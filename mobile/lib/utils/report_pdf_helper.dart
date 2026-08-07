import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/invoice_pdf_service.dart';

Future<void> generateAndOpenInvoiceReportPdf(
  BuildContext context, {
  String? status,
  String? customerName,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(content: Text('جاري إنشاء تقرير PDF...')),
  );

  try {
    final api = context.read<AuthProvider>().apiService;
    final report = await api.getReport(
      status: status,
      customerName: customerName,
    );
    final bytes = await InvoicePdfService.buildReport(report);
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(bytes, flush: true);
    await OpenFilex.open(file.path);
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
    );
  }
}
