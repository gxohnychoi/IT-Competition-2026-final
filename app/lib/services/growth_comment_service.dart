import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/growth_percentile_calculator.dart';
import '../models/models.dart';

class GrowthComment {
  final String title;
  final String body;
  final CommentLevel level;
  GrowthComment({required this.title, required this.body, required this.level});
}

enum CommentLevel { good, warning, info }

/// 성장 분석 코멘트를 만들어주는 서비스.
///
/// 기본은 질병관리청 2017 성장도표 LMS 데이터를 이용한 **실제 계산 기반**
/// 룰 코멘트로 동작해서 API 키 없이도 바로 작동함 — "또래 평균보다 몇 %
/// 크다/작다"는 문장이 실제 통계표를 근거로 나옴 (감으로 짜맞춘 수치 아님).
///
/// 실제 생성형 AI(Claude 등)로 문장 자체를 더 자연스럽게 다듬고 싶으면
/// [aiEndpoint]에 백엔드(Cloud Function 등) URL을 넣어주면 됨 — 이 경우
/// 계산된 수치(백분위, 퍼센트 차이)를 AI에게 넘겨서 문장만 생성하게 하는
/// 구조를 권장 (AI가 수치 자체를 지어내지 않도록). API 키는 앱에 직접
/// 넣지 말고 서버(Cloud Function)에서 보관해야 안전함.
class GrowthCommentService {
  GrowthCommentService._internal();
  static final instance = GrowthCommentService._internal();

  String? aiEndpoint;

  Future<List<GrowthComment>> generate(List<GrowthRecord> records, ChildProfile child) async {
    if (aiEndpoint != null) {
      try {
        return await _fetchFromAi(records, child);
      } catch (_) {
        return _ruleBased(records, child);
      }
    }
    return _ruleBased(records, child);
  }

  Future<List<GrowthComment>> _fetchFromAi(List<GrowthRecord> records, ChildProfile child) async {
    final res = await http.post(
      Uri.parse(aiEndpoint!),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'gender': child.gender,
        'birthDate': child.birthDate.toIso8601String(),
        'records': records
            .map((r) => {
                  'date': r.date.toIso8601String(),
                  'heightCm': r.heightCm,
                  'weightKg': r.weightKg,
                })
            .toList(),
      }),
    );
    final data = jsonDecode(res.body) as List;
    return data
        .map((e) => GrowthComment(
              title: e['title'] as String,
              body: e['body'] as String,
              level: CommentLevel.values.byName(e['level'] as String),
            ))
        .toList();
  }

  /// 질병관리청 2017 성장도표 LMS 데이터를 이용해:
  /// 1) 최신 측정값의 실제 백분위
  /// 2) 또래 평균(50th, 중앙값) 대비 몇 % 크거나 작은지
  /// 3) 최근 두 측정치 사이의 성장 속도 추세
  /// 를 계산해서 코멘트로 만듦.
  List<GrowthComment> _ruleBased(List<GrowthRecord> records, ChildProfile child) {
    if (records.isEmpty) {
      return [
        GrowthComment(
          title: '측정 기록이 없어요',
          body: '첫 측정 기록을 추가하면 분석이 시작됩니다.',
          level: CommentLevel.info,
        ),
      ];
    }

    final sorted = [...records]..sort((a, b) => a.date.compareTo(b.date));
    final latest = sorted.last;
    final isMale = child.gender.contains('남');
    final ageMonths = child.ageInMonthsAt(latest.date);

    final comments = <GrowthComment>[];

    // ── 키: 백분위 + 또래 평균 대비 퍼센트 차이 ──
    final heightPct = GrowthPercentileCalculator.heightPercentile(
      heightCm: latest.heightCm,
      ageInMonths: ageMonths,
      isMale: isMale,
    );
    final heightMedian = GrowthPercentileCalculator.valueAtPercentile(
      ageInMonths: ageMonths,
      percentile: 50,
      isMale: isMale,
      isHeight: true,
    );
    if (heightPct != null && heightMedian != null) {
      final diffPct = ((latest.heightCm - heightMedian) / heightMedian) * 100;
      final bigger = diffPct >= 0;
      final tone = heightPct >= 90 || heightPct <= 10
          ? CommentLevel.warning
          : CommentLevel.good;
      comments.add(GrowthComment(
        title: '키 ${heightPct.toStringAsFixed(0)}백분위',
        body: '또래 평균(50백분위, ${heightMedian.toStringAsFixed(1)}cm)보다 '
            '${diffPct.abs().toStringAsFixed(1)}% ${bigger ? '큽니다' : '작습니다'}. '
            '(질병관리청 2017 성장도표 기준)',
        level: tone,
      ));
    }

    // ── 몸무게: 백분위 + 또래 평균 대비 퍼센트 차이 ──
    final weightPct = GrowthPercentileCalculator.weightPercentile(
      weightKg: latest.weightKg,
      ageInMonths: ageMonths,
      isMale: isMale,
    );
    final weightMedian = GrowthPercentileCalculator.valueAtPercentile(
      ageInMonths: ageMonths,
      percentile: 50,
      isMale: isMale,
      isHeight: false,
    );
    if (weightPct != null && weightMedian != null) {
      final diffPct = ((latest.weightKg - weightMedian) / weightMedian) * 100;
      final bigger = diffPct >= 0;
      final tone = weightPct >= 90 || weightPct <= 10
          ? CommentLevel.warning
          : CommentLevel.good;
      comments.add(GrowthComment(
        title: '몸무게 ${weightPct.toStringAsFixed(0)}백분위',
        body: '또래 평균(50백분위, ${weightMedian.toStringAsFixed(1)}kg)보다 '
            '${diffPct.abs().toStringAsFixed(1)}% ${bigger ? '무겁습니다' : '가볍습니다'}. '
            '(질병관리청 2017 성장도표 기준)',
        level: tone,
      ));
    }

    // ── 체중 상태 (BMI 기준, 24개월 이상만 계산됨) ──
    final weightStatus = GrowthPercentileCalculator.weightStatusFromBmi(
      heightCm: latest.heightCm,
      weightKg: latest.weightKg,
      ageInMonths: ageMonths,
      isMale: isMale,
    );
    if (weightStatus != null) {
      final (title, body, level) = switch (weightStatus) {
        WeightStatus.underweight => (
            '저체중 주의',
            'BMI 백분위 5 미만 — 영양 상태를 소아과와 함께 확인해보세요.',
            CommentLevel.warning,
          ),
        WeightStatus.normal => (
            '정상 체중',
            'BMI 백분위가 정상 범위(5~84th) 안에 있어요.',
            CommentLevel.good,
          ),
        WeightStatus.overweight => (
            '과체중 주의',
            'BMI 백분위 85~94th — 식습관과 활동량을 함께 살펴봐주세요.',
            CommentLevel.warning,
          ),
        WeightStatus.obese => (
            '비만 위험',
            'BMI 백분위 95th 이상 — 소아과 상담을 권장합니다.',
            CommentLevel.warning,
          ),
      };
      comments.add(GrowthComment(title: title, body: body, level: level));
    }

    // ── 백분위 크로싱 감지 (임상적으로 의미 있는 신호) ──
    // 3/10/25/50/75/90/97 같은 주요 백분위선을 연속 두 측정 사이에
    // 2개 이상 가로지르면, 절댓값은 정상 범위 안이어도 성장 이상 신호로 봄
    // (단순 "평균보다 크다/작다"보다 임상적으로 더 유의미한 지표).
    if (sorted.length >= 2 && heightPct != null) {
      final prevRecord = sorted[sorted.length - 2];
      final prevAge = child.ageInMonthsAt(prevRecord.date);
      final prevHeightPct = GrowthPercentileCalculator.heightPercentile(
        heightCm: prevRecord.heightCm,
        ageInMonths: prevAge,
        isMale: isMale,
      );
      if (prevHeightPct != null) {
        final crossing = _crossedMajorLines(prevHeightPct, heightPct);
        if (crossing >= 2) {
          final direction = heightPct > prevHeightPct ? '상승' : '하락';
          comments.add(GrowthComment(
            title: '⚠️ 키 백분위 급격한 변화 감지',
            body: '직전 측정(${prevHeightPct.toStringAsFixed(0)}백분위) 대비 이번 측정(${heightPct.toStringAsFixed(0)}백분위)'
                '에서 주요 백분위선을 $crossing개 가로지르는 $direction이 있었어요. '
                '절댓값은 정상 범위 안이라도, 이런 "백분위 크로싱"은 소아과에서 성장 이상 신호로 보는 지표예요. '
                '전문의 상담을 권장합니다.',
            level: CommentLevel.warning,
          ));
        }
      }
    }

    if (heightPct == null && weightPct == null) {
      comments.add(GrowthComment(
        title: '분석 범위 밖이에요',
        body: '현재 나이(${ageMonths}개월)는 질병관리청 성장도표 데이터 범위(0~227개월) 밖이라 백분위 계산이 어려워요.',
        level: CommentLevel.info,
      ));
    }

    comments.add(GrowthComment(
      title: '참고용 안내',
      body: '본 분석은 참고용 지표입니다. 정확한 진단은 반드시 전문 의료진과 상담하세요. 질병관리청 2017 소아청소년 성장도표 기준.',
      level: CommentLevel.info,
    ));

    return comments;
  }

  /// 두 백분위 값 사이에 주요 백분위선(3/10/25/50/75/90/97)을 몇 개나
  /// 가로지르는지 계산. 예: 85백분위 → 40백분위면 75, 50선 2개를 가로지름.
  static const _majorLines = [3.0, 10.0, 25.0, 50.0, 75.0, 90.0, 97.0];

  int _crossedMajorLines(double from, double to) {
    final lo = from < to ? from : to;
    final hi = from < to ? to : from;
    return _majorLines.where((line) => line > lo && line < hi).length;
  }
}
