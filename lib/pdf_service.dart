import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  static Future<void> generateResultPdf({
    required String schoolName,
    required String studentName,
    required String studentClass,
    required String examName,
    required List<dynamic> subjectResults,
  }) async {
    final pdf = pw.Document();

    // Load fonts for multilingual support
    final arabicFont = await PdfGoogleFonts.notoNaskhArabicRegular();
    final latinFont = await PdfGoogleFonts.notoSansRegular();
    final latinBold = await PdfGoogleFonts.notoSansBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.purple, width: 2)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          schoolName,
                          style: pw.TextStyle(font: arabicFont, fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.purple900),
                          textDirection: pw.TextDirection.rtl,
                        ),
                        pw.Text('OFFICIAL ACADEMIC REPORT', style: pw.TextStyle(font: latinFont, fontSize: 10, color: PdfColors.grey700, letterSpacing: 1.5)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Date: ${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}', style: pw.TextStyle(font: latinFont, fontSize: 10)),
                        pw.Text('ID: ${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}', style: pw.TextStyle(font: latinFont, fontSize: 10, color: PdfColors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // Student Info Card
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  children: [
                    _infoRow('Student Name', studentName, latinFont, latinBold),
                    pw.SizedBox(height: 6),
                    _infoRow('Class', studentClass, latinFont, latinBold),
                    pw.SizedBox(height: 6),
                    _infoRow('Examination', examName, latinFont, latinBold),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // Results Table
              pw.Text('Subject Evaluation Results', style: pw.TextStyle(font: latinBold, fontSize: 14, color: PdfColors.purple)),
              pw.SizedBox(height: 12),
              pw.Table.fromTextArray(
                context: context,
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerStyle: pw.TextStyle(font: latinBold, fontSize: 11, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.purple700),
                cellStyle: pw.TextStyle(font: latinFont, fontSize: 10),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2.5),
                  1: pw.FlexColumnWidth(1),
                  2: pw.FlexColumnWidth(1),
                  3: pw.FlexColumnWidth(1),
                  4: pw.FlexColumnWidth(1.2),
                },
                data: <List<String>>[
                  <String>['Subject', 'Scored', 'Total', 'Grade', 'Status'],
                  ...subjectResults.map((s) {
                    final double scored = double.tryParse(s['scoredMark']?.toString() ?? '0') ?? 0;
                    final double total = double.tryParse(s['totalMarks']?.toString() ?? '100') ?? 100;
                    final double pct = (scored / total) * 100;
                    
                    String grade = 'D';
                    String status = 'Failed';
                    if (pct >= 40) status = 'Pass';
                    if (pct >= 90) grade = 'A+';
                    else if (pct >= 80) grade = 'A';
                    else if (pct >= 70) grade = 'B+';
                    else if (pct >= 60) grade = 'B';
                    else if (pct >= 50) grade = 'C+';

                    return [
                      s['subject'] ?? 'N/A',
                      scored.toString(),
                      total.toString(),
                      grade,
                      status
                    ];
                  }),
                ],
              ),
              
              pw.Spacer(),

              // Footer
              pw.Divider(color: PdfColors.grey300),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Authorized Signature', style: pw.TextStyle(font: latinFont, fontSize: 10, color: PdfColors.grey600)),
                  pw.Text('Generated by Harakat Al-Hayat Portal', style: pw.TextStyle(font: latinFont, fontSize: 9, color: PdfColors.grey400)),
                ],
              ),
            ],
          );
        },
      ),
    );

    // Provide the PDF data to the browser for download/print
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Result_${studentName}_${examName.replaceAll(' ', '_')}.pdf',
    );
  }

  static pw.Widget _infoRow(String label, String value, pw.Font font, pw.Font bold) {
    return pw.Row(
      children: [
        pw.SizedBox(width: 100, child: pw.Text(label, style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600))),
        pw.Text(': ', style: pw.TextStyle(font: font, fontSize: 10)),
        pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 11)),
      ],
    );
  }
}
