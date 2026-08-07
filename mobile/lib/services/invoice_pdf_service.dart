import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../utils/format.dart';

class InvoicePdfService {
  static final _date = DateFormat('yyyy-MM-dd');
  static final _dateTime = DateFormat('yyyy-MM-dd HH:mm');

  static String statusAr(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
        return 'مدفوعة';
      case 'PENDING':
        return 'معلقة';
      case 'DRAFT':
        return 'مسودة';
      case 'CANCELLED':
        return 'ملغاة';
      default:
        return status;
    }
  }

  static Future<Uint8List> buildReport(Map<String, dynamic> report) async {
    final arabicData = await rootBundle.load(
      'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    );
    final latinData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final arabic = pw.Font.ttf(arabicData);
    final latin = pw.Font.ttf(latinData);

    // Arabic primary + Latin fallback so INV-SEED / digits / "-" never become boxes.
    final theme = pw.ThemeData.withFont(
      base: arabic,
      bold: arabic,
      fontFallback: [latin],
    );

    final invoices = (report['invoices'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final count = report['count'] ?? invoices.length;
    final totalAmount = _asNum(report['totalAmount']);
    final filters = report['filters'] is Map
        ? Map<String, dynamic>.from(report['filters'] as Map)
        : <String, dynamic>{};
    final statusFilter = filters['status']?.toString();
    final customerFilter = filters['customerName']?.toString();

    final doc = pw.Document(theme: theme);
    final accent = PdfColor.fromInt(0xFF146B64);

    pw.Widget rtlText(
      String text, {
      double size = 11,
      PdfColor? color,
      pw.FontWeight? weight,
      pw.TextAlign align = pw.TextAlign.right,
    }) {
      return pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Text(
          text,
          textAlign: align,
          style: pw.TextStyle(
            fontSize: size,
            color: color,
            fontWeight: weight,
          ),
        ),
      );
    }

    pw.Widget ltrText(
      String text, {
      double size = 10,
      PdfColor? color,
      pw.TextAlign align = pw.TextAlign.center,
    }) {
      return pw.Directionality(
        textDirection: pw.TextDirection.ltr,
        child: pw.Text(
          text,
          textAlign: align,
          style: pw.TextStyle(fontSize: size, color: color),
        ),
      );
    }

    pw.Widget cell(
      pw.Widget child, {
      pw.Alignment align = pw.Alignment.center,
    }) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: pw.Align(alignment: align, child: child),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        theme: theme,
        textDirection: pw.TextDirection.rtl,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            rtlText(
              'تقرير الفواتير - محاسب بلس',
              size: 20,
              weight: pw.FontWeight.bold,
            ),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                ltrText(
                  _dateTime.format(DateTime.now()),
                  size: 11,
                  color: PdfColors.grey700,
                  align: pw.TextAlign.left,
                ),
                pw.SizedBox(width: 6),
                rtlText('تاريخ التقرير:', size: 11, color: PdfColors.grey700),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(color: accent, thickness: 1.2),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (context) => pw.Column(
          children: [
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 4),
            rtlText(
              'تم إنشاء هذا التقرير بواسطة مساعد المحاسبة الذكي - صفحة ${context.pageNumber} من ${context.pagesCount}',
              size: 9,
              color: PdfColors.grey600,
              align: pw.TextAlign.center,
            ),
          ],
        ),
        build: (context) {
          final rows = <pw.TableRow>[
            pw.TableRow(
              decoration: pw.BoxDecoration(color: accent),
              children: [
                cell(rtlText('المبلغ', size: 10, color: PdfColors.white, weight: pw.FontWeight.bold)),
                cell(rtlText('البنود', size: 10, color: PdfColors.white, weight: pw.FontWeight.bold)),
                cell(rtlText('الحالة', size: 10, color: PdfColors.white, weight: pw.FontWeight.bold)),
                cell(rtlText('التاريخ', size: 10, color: PdfColors.white, weight: pw.FontWeight.bold)),
                cell(rtlText('العميل', size: 10, color: PdfColors.white, weight: pw.FontWeight.bold)),
                cell(rtlText('الرقم', size: 10, color: PdfColors.white, weight: pw.FontWeight.bold)),
              ],
            ),
          ];

          for (var i = 0; i < invoices.length; i++) {
            final inv = invoices[i];
            final date = DateTime.tryParse(inv['date']?.toString() ?? '');
            rows.add(
              pw.TableRow(
                decoration: i.isOdd
                    ? const pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFFF7FAFA),
                      )
                    : null,
                children: [
                  cell(
                    rtlText(AppFormat.money(_asNum(inv['total'])), size: 9),
                    align: pw.Alignment.centerRight,
                  ),
                  cell(ltrText('${inv['itemsCount'] ?? '-'}', size: 9)),
                  cell(
                    rtlText(
                      statusAr(inv['status']?.toString() ?? ''),
                      size: 9,
                    ),
                  ),
                  cell(
                    ltrText(
                      date != null ? _date.format(date.toLocal()) : '-',
                      size: 9,
                    ),
                  ),
                  cell(
                    rtlText(inv['customer']?.toString() ?? '-', size: 9),
                    align: pw.Alignment.centerRight,
                  ),
                  cell(ltrText(inv['number']?.toString() ?? '-', size: 9)),
                ],
              ),
            );
          }

          return [
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFE8F5F3),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  rtlText('عدد الفواتير: $count'),
                  pw.SizedBox(height: 4),
                  rtlText('الإجمالي: ${AppFormat.money(totalAmount)}'),
                  if (statusFilter != null && statusFilter.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    rtlText('فلتر الحالة: ${statusAr(statusFilter)}'),
                  ],
                  if (customerFilter != null && customerFilter.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    rtlText('فلتر العميل: $customerFilter'),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            if (invoices.isEmpty)
              rtlText('لا توجد فواتير مطابقة للفلاتر.', size: 13)
            else
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.4),
                  1: pw.FlexColumnWidth(0.7),
                  2: pw.FlexColumnWidth(0.9),
                  3: pw.FlexColumnWidth(1.1),
                  4: pw.FlexColumnWidth(1.5),
                  5: pw.FlexColumnWidth(1.4),
                },
                children: rows,
              ),
          ];
        },
      ),
    );

    return doc.save();
  }

  static num _asNum(dynamic value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }
}
