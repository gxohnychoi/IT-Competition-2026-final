import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/models.dart';
import '../services/growth_comment_service.dart';
import 'growth_percentile_calculator.dart';

/// 소아과 방문 시 보여줄 수 있는 성장 기록 리포트 PDF를 만듦.
/// 측정 기록 표 + 최신 백분위 + 분석 코멘트를 한 장으로 정리.
class GrowthReportPdf {
  GrowthReportPdf._();

  static Future<void> generateAndShare({
    required ChildProfile child,
    required List<GrowthRecord> records,
    required List<GrowthComment> comments,
  }) async {
    final doc = pw.Document();
    final sorted = [...records]..sort((a, b) => a.date.compareTo(b.date));
    final isMale = child.gender.contains('남');

    // 한글이 네모(□)로 깨지지 않도록 Noto Sans KR 폰트를 명시적으로 로드해서
    // 페이지 테마 전체(기본체+굵은체)에 적용.
    final fontData = await rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf');
    final koreanFont = pw.Font.ttf(fontData);
    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      theme: pw.ThemeData.withFont(base: koreanFont, bold: koreanFont),
    );

    doc.addPage(
      pw.Page(
        pageTheme: pageTheme,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('쑥쑥이 성장 기록 리포트',
                  style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('발급일: ${DateFormat('yyyy년 M월 d일').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              pw.Divider(height: 24),

              // ── 아이 기본 정보 ──
              pw.Text('아이 정보', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Text('이름: ${child.name}'),
              pw.Text('성별: ${child.gender}'),
              pw.Text('생년월일: ${DateFormat('yyyy년 M월 d일').format(child.birthDate)}'),
              pw.Text('현재 나이: 생후 ${child.ageInMonths}개월'),
              pw.SizedBox(height: 20),

              // ── 최신 측정 요약 ──
              if (sorted.isNotEmpty) ...[
                pw.Text('최신 측정 요약', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                Builder2(sorted.last, child, isMale),
                pw.SizedBox(height: 20),
              ],

              // ── 측정 기록 표 ──
              pw.Text('측정 기록', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2),
                  1: pw.FlexColumnWidth(1.5),
                  2: pw.FlexColumnWidth(1.5),
                  3: pw.FlexColumnWidth(1.5),
                  4: pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.green50),
                    children: [
                      _cell('측정일', bold: true),
                      _cell('키(cm)', bold: true),
                      _cell('몸무게(kg)', bold: true),
                      _cell('키 백분위', bold: true),
                      _cell('몸무게 백분위', bold: true),
                    ],
                  ),
                  for (final r in sorted)
                    pw.TableRow(children: [
                      _cell(DateFormat('yyyy.MM.dd').format(r.date)),
                      _cell(r.heightCm.toStringAsFixed(1)),
                      _cell(r.weightKg.toStringAsFixed(1)),
                      _cell(_pctText(GrowthPercentileCalculator.heightPercentile(
                        heightCm: r.heightCm,
                        ageInMonths: child.ageInMonthsAt(r.date),
                        isMale: isMale,
                      ))),
                      _cell(_pctText(GrowthPercentileCalculator.weightPercentile(
                        weightKg: r.weightKg,
                        ageInMonths: child.ageInMonthsAt(r.date),
                        isMale: isMale,
                      ))),
                    ]),
                ],
              ),
              pw.SizedBox(height: 20),

              // ── 분석 코멘트 ──
              pw.Text('성장 분석 코멘트', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              for (final c in comments)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('• ${c.title}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      pw.Text(c.body, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                    ],
                  ),
                ),

              pw.Spacer(),
              pw.Divider(),
              pw.Text(
                '본 리포트는 질병관리청 2017 소아청소년 성장도표 기준 참고용 자료입니다. '
                '정확한 진단은 반드시 전문 의료진과 상담하세요.',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: '쑥쑥이_성장리포트_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  static pw.Widget _cell(String text, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(text,
            style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  static String _pctText(double? p) => p == null ? '-' : '${p.toStringAsFixed(0)}th';
}

/// 최신 측정 요약 박스 (별도 위젯 함수로 분리)
pw.Widget Builder2(GrowthRecord latest, ChildProfile child, bool isMale) {
  final heightPct = GrowthPercentileCalculator.heightPercentile(
    heightCm: latest.heightCm,
    ageInMonths: child.ageInMonthsAt(latest.date),
    isMale: isMale,
  );
  final weightPct = GrowthPercentileCalculator.weightPercentile(
    weightKg: latest.weightKg,
    ageInMonths: child.ageInMonthsAt(latest.date),
    isMale: isMale,
  );

  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: PdfColors.green50,
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('키 ${latest.heightCm}cm (${heightPct?.toStringAsFixed(0) ?? '-'}th 백분위)'),
        pw.Text('몸무게 ${latest.weightKg}kg (${weightPct?.toStringAsFixed(0) ?? '-'}th 백분위)'),
      ],
    ),
  );
}
