/*
  쑥쑥이 - RFID 찍고 거리(키) + 몸무게 측정 + OLED 표시 -> Firebase 전송
  ------------------------------------------------
  [업데이트] 등원/하원 판정 로직 추가
  - 오늘 같은 UID로 처음 태그 -> 등원 처리 (키/몸무게 측정 O)
  - 오늘 같은 UID로 두 번째 태그 -> 하원 처리 (측정 X, 시간만 기록)
  - 오늘 같은 UID로 세 번째 이상 태그 -> 새 세션으로 리셋 (다시 등원 처리)

  Firebase 구조:
  records/{UID}/{YYYY-MM-DD}
    - check_in_time, check_in_epoch
    - height_cm, weight_kg   (등원 시에만 기록)
    - check_out_time, check_out_epoch  (하원 시에만 추가)
    - status: "checked_in" | "checked_out"

  필요한 라이브러리 (Arduino IDE - 라이브러리 매니저에서 설치):
  - MFRC522 (by GithubCommunity / miguelbalboa)
  - VL53L0X (by Pololu)
  - Adafruit SSD1306
  - Adafruit GFX Library
  - HX711 (by bogde)
  - ArduinoJson (by Benoit Blanchon)   <-- 새로 추가됨
  - (WiFi, HTTPClient, time.h 는 ESP32 코어에 기본 포함)
*/

#include <SPI.h>
#include <MFRC522.h>
#include <Wire.h>
#include <VL53L0X.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <time.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <HX711.h>
#include <ArduinoJson.h>

// ===================== 핀 설정 (실제 배선에 맞게 수정) =====================
#define RFID_SS_PIN   5
#define RFID_RST_PIN  4
// SPI 기본 핀 (ESP32 기본값): SCK=18, MISO=19, MOSI=23

#define I2C_SDA 21
#define I2C_SCL 22

#define HEIGHT_OFFSET_CM 178.0
#define MAX_VALID_MM 8190

#define LOADCELL_DOUT_PIN 16
#define LOADCELL_SCK_PIN  17
#define CALIBRATION_FACTOR 21750.0
// ===================== 시연용 날짜 오프셋 =====================
int DEMO_DAY_OFFSET = 0;  // 0=오늘, -30=30일 전, -60=두 달 전 ... 원하는 값으로 조정 후 재업로드

#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64

// ===================== WiFi & Firebase 설정 =====================
const char* WIFI_SSID     = "G";
const char* WIFI_PASSWORD = "aaaaaaaa";
const char* FIREBASE_HOST = "https://it-competition-2026-default-rtdb.asia-southeast1.firebasedatabase.app";

// ===================== 객체 생성 =====================
MFRC522 rfid(RFID_SS_PIN, RFID_RST_PIN);
VL53L0X sensor;
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);
HX711 scale;

// ===================== OLED 메시지 =====================
void showMessage(String line1, String line2 = "") {
  display.clearDisplay();
  display.setTextSize(2);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 10);
  display.println(line1);
  if (line2 != "") {
    display.setTextSize(1);
    display.setCursor(0, 40);
    display.println(line2);
  }
  display.display();
}

// ===================== WiFi 연결 =====================
void connectWiFi() {
  Serial.print("WiFi 연결 중");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(300);
    Serial.print(".");
  }
  Serial.println("\nWiFi 연결됨! IP: " + WiFi.localIP().toString());
}

// ===================== NTP 시간 동기화 =====================
void syncTime() {
  configTime(9 * 3600, 0, "pool.ntp.org", "time.google.com");  // KST
  Serial.print("시간 동기화 중");
  time_t now = time(nullptr);
  while (now < 100000) {
    delay(300);
    Serial.print(".");
    now = time(nullptr);
  }
  Serial.println("\n시간 동기화 완료!");
}

// "YYYY-MM-DD HH:MM:SS"
String getTimeString() {
  time_t now = time(nullptr);
  now += (long)DEMO_DAY_OFFSET * 86400;   // <-- 이 줄만 추가
  struct tm* t = localtime(&now);
  char buf[25];
  sprintf(buf, "%04d-%02d-%02d %02d:%02d:%02d",
          t->tm_year + 1900, t->tm_mon + 1, t->tm_mday,
          t->tm_hour, t->tm_min, t->tm_sec);
  return String(buf);
}

// "YYYY-MM-DD" (Firebase 키로 사용, 오늘 날짜 판별용)
String getDateKey() {
  time_t now = time(nullptr);
  now += (long)DEMO_DAY_OFFSET * 86400;   // <-- 이 줄만 추가
  struct tm* t = localtime(&now);
  char buf[11];
  sprintf(buf, "%04d-%02d-%02d", t->tm_year + 1900, t->tm_mon + 1, t->tm_mday);
  return String(buf);
}

// unix epoch(초)
unsigned long getEpoch() {
  return (unsigned long)time(nullptr);
}

// ===================== RFID UID 읽기 =====================
String readRFID_UID() {
  String uidStr = "";
  for (byte i = 0; i < rfid.uid.size; i++) {
    if (rfid.uid.uidByte[i] < 0x10) uidStr += "0";
    uidStr += String(rfid.uid.uidByte[i], HEX);
  }
  uidStr.toUpperCase();
  return uidStr;
}

// ===================== 키 평균 측정 =====================
float measureHeightAvg(int numSamples = 10, int delayMs = 100) {
  float sum = 0;
  int validCount = 0;
  for (int i = 0; i < numSamples; i++) {
    int mm = sensor.readRangeContinuousMillimeters();
    if (mm < MAX_VALID_MM) {
      float measured_cm = mm / 10.0;
      float height_cm = HEIGHT_OFFSET_CM - measured_cm;
      sum += height_cm;
      validCount++;
    }
    delay(delayMs);
  }
  if (validCount == 0) return -1;
  return sum / validCount;
}

// ===================== 몸무게 평균 측정 =====================
float measureWeightAvg() {
  // 처음 7초 버리기
  unsigned long startTime = millis();
  while (millis() - startTime < 7000) {
    if (scale.is_ready()) scale.get_units(1);
    delay(100);
  }

  // 7~10초 사이 값 수집
  float samples[50];
  int validCount = 0;

  startTime = millis();
  while (millis() - startTime < 3000) {
    if (scale.is_ready() && validCount < 50) {
      float w = scale.get_units(3);
      if (w < 0) w = 0;
      samples[validCount] = w;
      validCount++;
    }
    delay(100);
  }

  if (validCount == 0) return -1;

  // 상위/하위 10% 제거 후 정렬
  int trimCount = validCount * 0.1;
  for (int i = 0; i < validCount - 1; i++) {
    for (int j = 0; j < validCount - i - 1; j++) {
      if (samples[j] > samples[j + 1]) {
        float temp = samples[j];
        samples[j] = samples[j + 1];
        samples[j + 1] = temp;
      }
    }
  }

  float sum = 0;
  int count = 0;
  for (int i = trimCount; i < validCount - trimCount; i++) {
    sum += samples[i];
    count++;
  }

  if (count == 0) return -1;
  float avg = sum / count;
  avg = avg + 5.0;
  return avg;
}

// ===================== Firebase GET: 오늘 기록 조회 =====================
// 반환값: httpCode (200이면 payload에 JSON 담김, "null"이면 기록 없음)
int getTodayRecord(String uid, String dateKey, String &payloadOut) {
  HTTPClient http;
  String url = String(FIREBASE_HOST) + "/records/" + uid + "/" + dateKey + ".json";
  http.begin(url);
  int httpCode = http.GET();
  if (httpCode > 0) {
    payloadOut = http.getString();
  } else {
    payloadOut = "null";
  }
  http.end();
  return httpCode;
}

// ===================== Firebase PUT: 기록 저장/덮어쓰기 =====================
void putTodayRecord(String uid, String dateKey, String jsonPayload) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi 연결 안 됨 - 전송 실패");
    return;
  }
  HTTPClient http;
  String url = String(FIREBASE_HOST) + "/records/" + uid + "/" + dateKey + ".json";
  http.begin(url);
  http.addHeader("Content-Type", "application/json");

  Serial.println("전송할 데이터: " + jsonPayload);
  int httpCode = http.PUT(jsonPayload);

  if (httpCode > 0) {
    Serial.printf("Firebase 응답 코드: %d\n", httpCode);
  } else {
    Serial.printf("전송 실패, 에러: %s\n", http.errorToString(httpCode).c_str());
  }
  http.end();
}

// ===================== 등원 처리 =====================
void handleCheckIn(String uid, String dateKey) {
  Serial.println(">> 등원 처리 시작");

  // 영점 조정
  showMessage("Taring...");
  delay(12000);
  scale.tare();
  Serial.println("영점 조정 완료");
  showMessage("Ready!", "10sec later...");

  Serial.println("10초 후 측정을 시작합니다...");
  delay(10000);

  showMessage("Measuring...");
  float heightCm = measureHeightAvg(10, 100);
  float weightKg = measureWeightAvg();
  String checkInTime = getTimeString();
  unsigned long checkInEpoch = getEpoch();

  if (heightCm < 0) {
    Serial.println("키 측정 실패");
    showMessage("failed");
  } else {
    String weightStr = (weightKg < 0) ? "N/A" : String(weightKg, 1) + " kg";
    Serial.printf("측정된 키: %.1f cm, 몸무게: %s\n", heightCm, weightStr.c_str());
    showMessage(String(heightCm, 1) + " cm", weightStr);
  }
  delay(3000);

  // JSON 구성
  String payload = "{";
  payload += "\"uid\":\"" + uid + "\",";
  payload += "\"height_cm\":" + String(heightCm, 1) + ",";
  payload += "\"weight_kg\":" + String(weightKg, 1) + ",";
  payload += "\"check_in_time\":\"" + checkInTime + "\",";
  payload += "\"check_in_epoch\":" + String(checkInEpoch) + ",";
  payload += "\"status\":\"checked_in\"";
  payload += "}";

  putTodayRecord(uid, dateKey, payload);

  showMessage("Welcome!", "Checked In");
  delay(2000);
}

// ===================== 하원 처리 =====================
// existingPayload: 아까 GET으로 받아온 오늘 기존 기록 (check_in 정보 유지하기 위해 필요)
void handleCheckOut(String uid, String dateKey, String existingPayload) {
  Serial.println(">> 하원 처리 시작");
  showMessage("Bye Bye!", "Checking out...");

  // 기존 JSON 파싱해서 필드 유지
  JsonDocument doc;
  DeserializationError err = deserializeJson(doc, existingPayload);
  if (err) {
    Serial.println("JSON 파싱 실패, 하원 처리 중단");
    showMessage("Error!");
    delay(2000);
    return;
  }

  String checkOutTime = getTimeString();
  unsigned long checkOutEpoch = getEpoch();

  doc["check_out_time"] = checkOutTime;
  doc["check_out_epoch"] = checkOutEpoch;
  doc["status"] = "checked_out";

  String payload;
  serializeJson(doc, payload);

  putTodayRecord(uid, dateKey, payload);

  showMessage("Goodbye!", "Checked Out");
  delay(2000);
}

// ===================== setup =====================
void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println("\n=== 쑥쑥이 시작 ===");

  connectWiFi();
  syncTime();

  SPI.begin();
  rfid.PCD_Init();
  Serial.println("RC522 준비 완료. 카드를 태그해주세요.");

  Wire.begin(I2C_SDA, I2C_SCL);
  sensor.setTimeout(500);
  if (!sensor.init()) {
    Serial.println("VL53L0X 초기화 실패! 배선 확인 필요");
    while (1) delay(1000);
  }
  sensor.startContinuous();
  Serial.println("VL53L0X 준비 완료.");

  scale.begin(LOADCELL_DOUT_PIN, LOADCELL_SCK_PIN);
  scale.set_scale(CALIBRATION_FACTOR);
  scale.tare();
  Serial.println("HX711 준비 완료.");

  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println("OLED 초기화 실패!");
    while (1) delay(1000);
  }
  Serial.println("OLED 준비 완료.");
  showMessage("Tag Your", "Card Please");
}

// ===================== loop =====================
void loop() {
  if (!rfid.PICC_IsNewCardPresent() || !rfid.PICC_ReadCardSerial()) {
    return;
  }

  String uid = readRFID_UID();
  String dateKey = getDateKey();

  Serial.println("----------------------------------");
  Serial.println("카드 감지! UID: " + uid + " / 날짜: " + dateKey);

  // 오늘 기존 기록 조회
  showMessage("Checking...");
  String existingPayload;
  getTodayRecord(uid, dateKey, existingPayload);
  Serial.println("기존 기록 조회 결과: " + existingPayload);

  bool hasRecord = (existingPayload != "null" && existingPayload.length() > 0);
  bool hasCheckOut = hasRecord && (existingPayload.indexOf("check_out_time") != -1);

  if (!hasRecord) {
    // Case 1: 오늘 첫 태그 -> 등원
    handleCheckIn(uid, dateKey);
  } else if (!hasCheckOut) {
    // Case 2: 등원만 있고 하원 없음 -> 하원 처리
    handleCheckOut(uid, dateKey, existingPayload);
  } else {
    // Case 3: 등원+하원 둘 다 있음 -> 새 세션으로 리셋, 다시 등원 처리
    Serial.println("오늘 이미 등하원 완료됨 -> 새 세션으로 재시작");
    handleCheckIn(uid, dateKey);
  }

  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();

  showMessage("Tag Your", "Card Please");
  delay(2000);
}
