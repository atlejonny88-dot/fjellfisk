import 'dart:convert';

import 'package:fjellfisk/models/diary_entry.dart';
import 'package:fjellfisk/services/diary_print_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dagbok-PDF støtter norsk tekst og produserer en gyldig fil', () async {
    final entry = DiaryEntry(
      id: 'test',
      title: 'Fôring og vedlikehold',
      body: 'Test med æ, ø, å og CO₂.',
      category: 'Fôring',
      createdAt: DateTime(2026, 9, 6, 12, 30),
      createdByUid: 'uid',
      createdByEmail: 'ansatt@example.com',
      createdByName: 'Test Ansatt',
      updatedAt: DateTime(2026, 9, 6, 12, 30),
      updatedByUid: 'uid',
      updatedByEmail: 'ansatt@example.com',
      entryDate: DateTime(2026, 9, 6, 12, 30),
      status: 'active',
    );

    final bytes = await DiaryPrintService.buildPdf(
      format: PdfPageFormat.a4,
      facilityName: 'Arctic Hardanger',
      periodLabel: 'September 2026',
      entries: [entry],
    );

    expect(bytes.length, greaterThan(1000));
    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
  });
}
