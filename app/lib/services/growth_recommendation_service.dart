import 'package:flutter/material.dart';
import '../core/growth_percentile_calculator.dart';

/// 신체활동 / 근육발달 / 식습관 추천 카드 하나
class GrowthRecommendation {
  final String category; // '신체활동' | '근육발달' | '식습관'
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  GrowthRecommendation({
    required this.category,
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });
}

/// 비만/저체중 판정(WeightStatus) + 나이를 기준으로 맞춤 추천 3개를 만듦.
///
/// 근거자료: docs/health_recommendation_research.md 참고
/// (WHO·보건복지부 신체활동 지침, 질병관리청 소아청소년 비만 예방관리수칙,
///  한국영양학회 영양소 섭취기준 등 공식 자료 기반으로 문구 구성)
class GrowthRecommendationService {
  GrowthRecommendationService._();

  static List<GrowthRecommendation> generate({
    required WeightStatus status,
    required int ageInMonths,
  }) {
    final ageYears = ageInMonths ~/ 12;
    final isPuberty = ageYears >= 12; // 사춘기(중고등학생) 여부 — 골격 발달 문구 분기용
    final isElementary = ageYears >= 6 && ageYears < 12;

    return [
      _activityRecommendation(status: status, isPuberty: isPuberty, isElementary: isElementary),
      _dietRecommendation(status),
    ];
  }

  // ── 신체활동 추천 ──
  // 근거: WHO Guidelines on Physical Activity and Sedentary Behaviour (2020),
  //       보건복지부·한국건강증진개발원「한국인을 위한 신체활동 지침」(2023 개정판),
  //       질병관리청·대한비만학회「소아청소년 비만 예방관리수칙」(2026.3)
  static GrowthRecommendation _activityRecommendation({
    required WeightStatus status,
    required bool isPuberty,
    required bool isElementary,
  }) {
    final ageNote = isPuberty
        ? '사춘기엔 스마트폰·SNS 사용 시간이 자연스럽게 늘어나기 쉬워요. 하루 사용 시간을 2시간 이내로 정해두고, 등하굣길 걷기나 계단 이용처럼 일상 속 움직임부터 늘려보세요. 여기에 줄넘기·자전거·배드민턴 같은 유산소 운동을 주 3회 이상 더하면 성장기 체력 관리에 큰 도움이 돼요.'
        : isElementary
            ? '이 시기엔 정해진 운동보다 신나게 노는 것 자체가 최고의 운동이에요. 술래잡기, 줄넘기, 자전거 타기처럼 친구들과 몸을 쓰며 노는 시간을 하루 60분 이상 확보해주시고, 체육 시간이나 놀이터에서의 자유놀이도 충분히 인정해주세요.'
            : '뛰기, 기어오르기, 공놀이처럼 몸 전체를 쓰는 놀이가 이 시기 발달에 큰 도움이 돼요. 짧은 시간이라도 매일 반복해서 움직이는 습관을 만들어주는 게 중요해요.';

    final statusNote = switch (status) {
      WeightStatus.obese ||
      WeightStatus.overweight =>
        ' 다만 강도 높은 운동을 한 번에 몰아서 하기보다, 매일 조금씩 꾸준히 움직이는 습관이 훨씬 효과적이에요. 30분마다 한 번씩 앉아있는 시간을 끊어주는 것만으로도 도움이 됩니다.',
      WeightStatus.underweight => ' 고강도 운동보다는 몸을 자주 움직이는 습관 자체를 먼저 만들어보세요. 활동량이 늘면 자연스럽게 식욕도 함께 느는 경우가 많아요.',
      WeightStatus.normal => ' 지금의 활동량을 잘 유지하고 있어요 — 이 습관 그대로 이어가 주세요.',
    };

    return GrowthRecommendation(
      category: '신체활동',
      icon: Icons.directions_run_rounded,
      color: const Color(0xFF4A7FD6),
      title: '하루 60분, 몸을 움직여요',
      body: '$ageNote$statusNote',
    );
  }

  // ── 식습관 추천 ──
  // 근거: 보건복지부·농림축산식품부·식약처「한국인을 위한 식생활지침」(2021),
  //       질병관리청 국가건강정보포털 소아·청소년 식이영양,
  //       한국영양학회「한국인 영양소 섭취기준」
  static GrowthRecommendation _dietRecommendation(WeightStatus status) {
    final (title, body) = switch (status) {
      WeightStatus.underweight => (
          '단백질·칼슘·철분을 챙겨주세요',
          '계란, 우유, 소고기·닭고기 같은 살코기, 두부·콩류처럼 단백질이 풍부한 음식을 세 끼 식사에 고르게 포함해보세요. 특히 성장기에는 칼슘과 철분 섭취가 골격 형성에 중요한 역할을 해요. 억지로 많이 먹이기보다, 정해진 시간에 규칙적으로 잘 먹는 습관을 먼저 만드는 게 우선이에요.',
        ),
      WeightStatus.normal => (
          '지금처럼 균형 잡힌 식사를 유지해요',
          '밥과 반찬을 골고루 먹는 지금의 식습관이 참 좋아요. 다만 과자·음료처럼 첨가당이 많은 간식은 하루 섭취 열량의 10% 이내로 관리하는 게 좋고(세계보건기구 권고 기준), 나트륨 많은 가공식품보다는 신선한 재료 위주의 식사를 이어가 주세요.',
        ),
      WeightStatus.overweight => (
          '간식과 음료만 살짝 바꿔볼까요',
          '과자·아이스크림 대신 제철 과일이나 무염 견과류로, 탄산음료·주스 대신 물이나 무가당 음료로 바꿔보는 것만으로도 큰 변화를 만들 수 있어요. 아침을 거르면 다음 식사량이 오히려 늘어나기 쉬우니, 가볍더라도 아침 식사는 꼭 챙겨주세요.',
        ),
      WeightStatus.obese => (
          '규칙적인 식사가 다이어트보다 우선이에요',
          '무리하게 양을 줄이기보다, 하루 세 끼를 정해진 시간에 규칙적으로 먹는 것부터 시작해보세요. 밥그릇 크기를 조금 줄이거나 채소 반찬을 먼저 먹는 습관도 도움이 됩니다. 체중계 숫자보다, 아이가 건강하게 자라는 과정 자체에 함께 집중해주세요.',
        ),
    };

    return GrowthRecommendation(
      category: '식습관',
      icon: Icons.restaurant_rounded,
      color: const Color(0xFFC98A1E),
      title: title,
      body: body,
    );
  }
}
