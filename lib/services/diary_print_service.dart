import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/diary_entry.dart';
import 'diary_pdf_exporter.dart';

class DiaryPrintService {
  static final DateFormat _dateTimeFormat = DateFormat('dd.MM.yyyy HH:mm');

  static Future<void> printEntry({
    required DiaryEntry entry,
    required String facilityName,
  }) async {
    final date = entry.displayDate ?? DateTime.now();
    await _print(
      fileName:
          'fjellfisk_dagbok_${DateFormat('yyyy-MM-dd_HHmm').format(date)}.pdf',
      facilityName: facilityName,
      periodLabel: _dateTimeFormat.format(date),
      entries: [entry],
    );
  }

  static Future<void> printPeriod({
    required List<DiaryEntry> entries,
    required String facilityName,
    required String periodLabel,
    required String fileName,
  }) async {
    await _print(
      fileName: fileName,
      facilityName: facilityName,
      periodLabel: periodLabel,
      entries: entries,
    );
  }

  static Future<void> _print({
    required String fileName,
    required String facilityName,
    required String periodLabel,
    required List<DiaryEntry> entries,
  }) async {
    final bytes = await buildPdf(
      format: PdfPageFormat.a4,
      facilityName: facilityName,
      periodLabel: periodLabel,
      entries: entries,
    );
    await DiaryPdfExporter.export(bytes, fileName);
  }

  static Future<Uint8List> buildPdf({
    required PdfPageFormat format,
    required String facilityName,
    required String periodLabel,
    required List<DiaryEntry> entries,
  }) async {
    final document = pw.Document(
      title: 'Fjellfisk Dagbok / Driftslogg',
      author: 'Arctic Hardanger',
    );
    final regularData = await rootBundle.load('assets/fonts/DejaVuSans.ttf');
    final boldData = await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf');
    final regular = pw.Font.ttf(regularData);
    final bold = pw.Font.ttf(boldData);

    document.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(36),
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Fjellfisk',
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey900,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              _pdfText(facilityName),
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.blueGrey600,
              ),
            ),
            pw.Divider(color: PdfColors.blueGrey200),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Side ${context.pageNumber} av ${context.pagesCount}',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.blueGrey600,
            ),
          ),
        ),
        build: (context) => [
          pw.Text(
            'Dagbok / Driftslogg',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            _pdfText(periodLabel),
            style: const pw.TextStyle(color: PdfColors.blueGrey700),
          ),
          pw.SizedBox(height: 18),
          if (entries.isEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColors.blueGrey50,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text('Ingen innlegg i valgt periode.'),
            )
          else
            ...entries.map(_entryBlock),
        ],
      ),
    );

    return document.save();
  }

  static pw.Widget _entryBlock(DiaryEntry entry) {
    final date = entry.displayDate;
    final dateText =
        date == null ? 'Dato mangler' : _dateTimeFormat.format(date);
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blueGrey200),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Text(
                  _pdfText(entry.title),
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Text(
                _pdfText(entry.category),
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.blue700,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            '${_pdfText(dateText)} | ${_pdfText(entry.authorLabel)}',
            style: const pw.TextStyle(
              fontSize: 10,
              color: PdfColors.blueGrey600,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(_pdfText(entry.body), style: const pw.TextStyle(height: 1.4)),
        ],
      ),
    );
  }

  static String _pdfText(String value) {
    return value
        .replaceAll('\u2013', '-')
        .replaceAll('\u2014', '-')
        .replaceAll('\u2018', "'")
        .replaceAll('\u2019', "'")
        .replaceAll('\u201C', '"')
        .replaceAll('\u201D', '"')
        .replaceAll('\u00A0', ' ');
  }
}
