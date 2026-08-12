/**
 * 쑥쑥이 - 성장 분석 코멘트 생성 Cloud Function
 *
 * 앱(Flutter)이 계산한 "수치"(백분위, 또래 평균 대비 %, 크로싱 여부)를
 * 받아서 Claude API로 자연스러운 문장만 생성함. 수치 자체는 이미
 * 질병관리청 데이터로 정확히 계산된 값이라, AI에게 수치를 새로 만들어내게
 * 하지 않고 "이 수치를 보호자가 이해하기 쉬운 문장으로 바꿔줘"라고만
 * 시키는 구조 — AI가 틀린 숫자를 지어내는 걸 방지함.
 *
 * 배포 방법:
 *   cd functions
 *   npm install
 *   firebase functions:secrets:set ANTHROPIC_API_KEY
 *   firebase deploy --only functions
 *
 * 배포 후 나오는 URL을 Flutter 앱의
 *   GrowthCommentService.instance.aiEndpoint = '그 URL';
 * 에 넣어주면 이 함수가 호출됨 (실패 시 앱이 자동으로 로컬 룰 기반으로 폴백).
 */

const {onRequest} = require("firebase-functions/v2/https");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {defineSecret} = require("firebase-functions/params");
const admin = require("firebase-admin");

admin.initializeApp();

const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");

/**
 * [비활성화됨] users/{uid}/children/{childId}/growthRecords 새 기록 시 알림.
 * → 등원 시점에 height_cm/weight_kg가 같이 기록되기 때문에, 아래
 *   notifyOnAttendanceEvent(등원 알림)이랑 같은 순간에 겹쳐서 알림이
 *   두 번 가는 문제가 있어 잠깐 꺼둠. 필요하면 exports 줄만 살리면 됨.
 */
/* exports.notifyOnNewMeasurement = onDocumentCreated(
  {document: "users/{uid}/children/{childId}/growthRecords/{recordId}", region: "asia-northeast3"},
  async (event) => {
    const {uid, childId} = event.params;
    const record = event.data.data();

    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    const token = userDoc.data()?.fcmToken;
    if (!token) return; // 알림 권한 안 받았거나 토큰 없으면 조용히 종료

    const childDoc = await admin
      .firestore()
      .collection("users")
      .doc(uid)
      .collection("children")
      .doc(childId)
      .get();
    const childName = childDoc.data()?.name || "아이";

    await admin.messaging().send({
      token,
      notification: {
        title: `${childName} 측정 완료 📏`,
        body: `키 ${record.heightCm}cm · 몸무게 ${record.weightKg}kg 측정됐어요.`,
      },
      webpush: {
        fcmOptions: {link: "/"},
      },
    });
  }
); */

/**
 * users/{uid}/children/{childId}/attendanceEvents 에 등원/하원 이벤트가
 * 새로 기록되면 실행됨. 학부모가 설정에서 꺼둔 알림 종류는 보내지 않음
 * (notifyCheckIn / notifyCheckOut 필드, 기본값 true).
 */
exports.notifyOnAttendanceEvent = onDocumentCreated(
  {document: "users/{uid}/children/{childId}/attendanceEvents/{eventId}", region: "asia-northeast3"},
  async (event) => {
    const {uid, childId} = event.params;
    const eventData = event.data.data();
    const type = eventData.type; // 'checkin' | 'checkout'

    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    const userData = userDoc.data();
    const token = userData?.fcmToken;
    if (!token) return;

    const prefKey = type === "checkin" ? "notifyCheckIn" : "notifyCheckOut";
    const enabled = userData?.[prefKey] ?? true; // 설정 안 했으면 기본 켜짐
    if (!enabled) return; // 학부모가 이 알림을 꺼뒀으면 조용히 종료

    const childDoc = await admin
      .firestore()
      .collection("users")
      .doc(uid)
      .collection("children")
      .doc(childId)
      .get();
    const childName = childDoc.data()?.name || "아이";

    const isCheckIn = type === "checkin";
    await admin.messaging().send({
      token,
      notification: {
        title: isCheckIn ? `${childName} 등원했어요 🏠` : `${childName} 하원했어요 👋`,
        body: isCheckIn ? "오늘도 씩씩하게 등원했어요!" : "오늘 하루도 수고 많았어요!",
      },
      webpush: {
        fcmOptions: {link: "/"},
      },
    });
  }
);

exports.growthComment = onRequest(
  {secrets: [ANTHROPIC_API_KEY], cors: true, region: "asia-northeast3"},
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("POST만 지원합니다.");
      return;
    }

    try {
      const {gender, birthDate, records} = req.body;

      if (!records || records.length === 0) {
        res.json([
          {
            title: "측정 기록이 없어요",
            body: "첫 측정 기록을 추가하면 분석이 시작됩니다.",
            level: "info",
          },
        ]);
        return;
      }

      const sorted = [...records].sort(
        (a, b) => new Date(a.date) - new Date(b.date)
      );
      const latest = sorted[sorted.length - 1];
      const prev = sorted.length >= 2 ? sorted[sorted.length - 2] : null;

      // Claude에게 넘길 프롬프트 — 수치는 이미 계산되어 있다고 가정하고
      // 문장 생성만 맡김 (앱에서 계산된 값을 그대로 같이 전달).
      const prompt = `너는 영유아 성장 데이터를 보호자에게 설명해주는 도우미야.
아래 측정 데이터를 보고, 보호자가 이해하기 쉬운 성장 분석 코멘트를 한국어로 2~4개 만들어줘.

성별: ${gender}
생년월일: ${birthDate}
최신 측정: ${latest.date}, 키 ${latest.heightCm}cm, 몸무게 ${latest.weightKg}kg
${prev ? `직전 측정: ${prev.date}, 키 ${prev.heightCm}cm, 몸무게 ${prev.weightKg}kg` : "직전 측정 없음"}

반드시 아래 JSON 배열 형식으로만 답해 (다른 텍스트 없이):
[{"title": "제목(10자 이내)", "body": "설명(80자 이내, 따뜻하고 친근한 말투)", "level": "good|warning|info"}]

주의: 백분위나 구체적인 %수치는 네가 계산하지 말고, 성장 속도의 경향(꾸준함/빠름/느림)과
정서적으로 안심시키는 톤 위주로 작성해줘. 마지막엔 반드시 "참고용 지표이며 정확한 진단은
전문의와 상담하라"는 안내 문구를 level:"info"로 하나 포함해줘.`;

      const response = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": ANTHROPIC_API_KEY.value(),
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({
          model: "claude-sonnet-4-6",
          max_tokens: 800,
          messages: [{role: "user", content: prompt}],
        }),
      });

      const data = await response.json();
      const text = data.content?.[0]?.text ?? "[]";
      const cleaned = text.replace(/```json|```/g, "").trim();
      const comments = JSON.parse(cleaned);

      res.json(comments);
    } catch (err) {
      console.error("growthComment 에러:", err);
      res.status(500).json({error: String(err)});
    }
  }
);
