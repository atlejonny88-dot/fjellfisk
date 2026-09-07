import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../models/production_report.dart';
import 'excel_downloader.dart';

class ExcelService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  static Future<String?> exportFacility({
    required String facilityId,
    required String facilityName,
  }) async {
    final excel = Excel.createExcel();
    const sheetName = 'Anlegg';
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    _deleteDefaultSheet(excel);

    _appendHeader(sheet);

    final facilitySnap =
        await _db.collection('facilities').doc(facilityId).get();
    final facilityData = facilitySnap.data();
    final resolvedFacilityName = _firstText([
      facilityName,
      facilityData?['name'],
      facilityData?['facilityName'],
      facilityId,
    ]);

    final sections = await _db
        .collection('facilities')
        .doc(facilityId)
        .collection('sections')
        .get();

    for (final section in sections.docs) {
      final sectionData = section.data();
      final sectionName = _firstText([
        sectionData['name'],
        sectionData['sectionName'],
        section.id,
      ]);

      final tanks = await section.reference.collection('tanks').get();

      for (final tank in tanks.docs) {
        final tankData = tank.data();
        final tankName = _firstText([
          tankData['name'],
          tankData['tankName'],
          tank.id,
        ]);
        final fishCount = _firstValue([
          tankData['fishCount'],
          tankData['fish_count'],
          tankData['count'],
        ]);

        final logs =
            await tank.reference.collection('logs').orderBy('date').get();

        if (logs.docs.isEmpty) {
          _appendExportRow(
            sheet,
            facilityName: resolvedFacilityName,
            sectionName: sectionName,
            tankName: tankName,
            fishCount: fishCount,
            logData: const <String, dynamic>{},
          );
          continue;
        }

        for (final log in logs.docs) {
          _appendExportRow(
            sheet,
            facilityName: resolvedFacilityName,
            sectionName: sectionName,
            tankName: tankName,
            fishCount: fishCount,
            logData: log.data(),
          );
        }
      }
    }

    return ExcelDownloader.download(
      excel,
      '${_safeFileName(resolvedFacilityName)}.xlsx',
    );
  }

  static Future<String?> exportTank({
    required String facilityId,
    required String sectionId,
    required String tankId,
    required String tankName,
  }) async {
    final excel = Excel.createExcel();
    const sheetName = 'Kar';
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    _deleteDefaultSheet(excel);

    _appendHeader(sheet);

    final facilityRef = _db.collection('facilities').doc(facilityId);
    final facilitySnap = await facilityRef.get();
    final sectionSnap =
        await facilityRef.collection('sections').doc(sectionId).get();
    final tankSnap =
        await sectionSnap.reference.collection('tanks').doc(tankId).get();

    final facilityData = facilitySnap.data();
    final sectionData = sectionSnap.data();
    final tankData = tankSnap.data();

    final resolvedFacilityName = _firstText([
      facilityData?['name'],
      facilityData?['facilityName'],
      facilityId,
    ]);
    final sectionName = _firstText([
      sectionData?['name'],
      sectionData?['sectionName'],
      sectionId,
    ]);
    final resolvedTankName = _firstText([
      tankName,
      tankData?['name'],
      tankData?['tankName'],
      tankId,
    ]);
    final fishCount = _firstValue([
      tankData?['fishCount'],
      tankData?['fish_count'],
      tankData?['count'],
    ]);

    final logs =
        await tankSnap.reference.collection('logs').orderBy('date').get();

    if (logs.docs.isEmpty) {
      _appendExportRow(
        sheet,
        facilityName: resolvedFacilityName,
        sectionName: sectionName,
        tankName: resolvedTankName,
        fishCount: fishCount,
        logData: const <String, dynamic>{},
      );
    } else {
      for (final log in logs.docs) {
        _appendExportRow(
          sheet,
          facilityName: resolvedFacilityName,
          sectionName: sectionName,
          tankName: resolvedTankName,
          fishCount: fishCount,
          logData: log.data(),
        );
      }
    }

    return ExcelDownloader.download(
      excel,
      '${_safeFileName(resolvedTankName)}.xlsx',
    );
  }

  static Future<String?> exportProductionReport({
    required ProductionReport report,
    required String facilityName,
  }) async {
    final excel = Excel.createExcel();
    const summaryName = 'Sammendrag';
    final summary = excel[summaryName];
    final tanks = excel['Karoversikt'];
    final logs = excel['Registreringer'];
    excel.setDefaultSheet(summaryName);
    _deleteDefaultSheet(excel);

    summary.appendRow([
      TextCellValue('Produksjonsrapport'),
      TextCellValue(facilityName),
    ]);
    summary.appendRow([
      TextCellValue('Periode'),
      TextCellValue('${_dateFormat.format(report.from)} - '
          '${_dateFormat.format(report.to)}'),
    ]);
    summary.appendRow([
      TextCellValue('Filter'),
      TextCellValue(report.filterLabel),
    ]);
    summary.appendRow([]);
    summary.appendRow([
      TextCellValue('KPI'),
      TextCellValue('Verdi'),
    ]);
    summary.appendRow([
      TextCellValue('Fôr brukt'),
      DoubleCellValue(report.feedKg),
    ]);
    summary.appendRow([
      TextCellValue('Dødelighet'),
      IntCellValue(report.mortality),
    ]);
    summary.appendRow([
      TextCellValue('Registrert biomasse kg'),
      DoubleCellValue(report.biomassKg),
    ]);
    summary.appendRow([
      TextCellValue('Siste snittvekt g'),
      _doubleOrText(report.latestAvgWeight, 'Ikke nok data'),
    ]);
    summary.appendRow([
      TextCellValue('Vektendring g'),
      _doubleOrText(report.weightChange, 'Ikke nok data'),
    ]);
    summary.appendRow([
      TextCellValue('FCR'),
      report.fcr == null
          ? TextCellValue('FCR kan ikke beregnes')
          : DoubleCellValue(report.fcr!),
    ]);
    summary.appendRow([
      TextCellValue('Aktive kar'),
      IntCellValue(report.activeTanks),
    ]);
    summary.appendRow([
      TextCellValue('Tomme kar'),
      IntCellValue(report.emptyTanks),
    ]);
    summary.appendRow([
      TextCellValue('Registreringer'),
      IntCellValue(report.registrations),
    ]);
    summary.appendRow([
      TextCellValue('Temperatur gjennomsnitt'),
      report.avgTemperature == null
          ? TextCellValue('Ikke nok data')
          : DoubleCellValue(report.avgTemperature!),
    ]);
    summary.appendRow([
      TextCellValue('Temperatur minimum'),
      report.minTemperature == null
          ? TextCellValue('Ikke nok data')
          : DoubleCellValue(report.minTemperature!),
    ]);
    summary.appendRow([
      TextCellValue('Temperatur maksimum'),
      report.maxTemperature == null
          ? TextCellValue('Ikke nok data')
          : DoubleCellValue(report.maxTemperature!),
    ]);

    tanks.appendRow([
      TextCellValue('Seksjon'),
      TextCellValue('Kar'),
      TextCellValue('Fisk'),
      TextCellValue('Snittvekt'),
      TextCellValue('Biomasse'),
      TextCellValue('Fôr'),
      TextCellValue('Dødelighet'),
      TextCellValue('FCR'),
      TextCellValue('Temperatur'),
    ]);
    for (final row in report.tanks) {
      tanks.appendRow([
        TextCellValue(row.sectionName),
        TextCellValue(row.tankName),
        IntCellValue(row.fishCount),
        _doubleOrText(row.latestWeight, 'Ikke nok data'),
        _doubleOrText(row.biomassKg, 'Ikke nok data'),
        DoubleCellValue(row.feedKg),
        IntCellValue(row.mortality),
        row.fcr == null
            ? TextCellValue('Ikke nok data')
            : DoubleCellValue(row.fcr!),
        row.latestTemperature == null
            ? TextCellValue('Ikke nok data')
            : DoubleCellValue(row.latestTemperature!),
      ]);
    }

    logs.appendRow([
      TextCellValue('Dato'),
      TextCellValue('Seksjon'),
      TextCellValue('Kar'),
      TextCellValue('Dødelighet'),
      TextCellValue('Fôr'),
      TextCellValue('Snittvekt'),
      TextCellValue('Temperatur'),
      TextCellValue('Fôrtype'),
      TextCellValue('Pelletstørrelse'),
    ]);
    for (final log in report.registrationsList) {
      logs.appendRow([
        TextCellValue(_dateFormat.format(log.date)),
        TextCellValue(log.sectionName),
        TextCellValue(log.tankName),
        IntCellValue(log.mortality),
        DoubleCellValue(log.feedKg),
        _doubleOrText(log.avgWeight, ''),
        _doubleOrText(log.temperature, ''),
        TextCellValue(log.feedType),
        _doubleOrText(log.pelletSizeMm, ''),
      ]);
    }

    final fileName =
        'produksjonsrapport_${_safeFileName(report.filterLabel)}_${DateFormat('yyyyMMdd').format(report.from)}_${DateFormat('yyyyMMdd').format(report.to)}.xlsx';
    return ExcelDownloader.download(excel, fileName);
  }

  static void _appendHeader(Sheet sheet) {
    sheet.appendRow([
      TextCellValue('Anleggsnavn'),
      TextCellValue('Seksjon/bygg'),
      TextCellValue('Kar'),
      TextCellValue('Fisketall'),
      TextCellValue('Dato'),
      TextCellValue('Dødelighet'),
      TextCellValue('Fôr kg'),
      TextCellValue('Temperatur'),
      TextCellValue('Snittvekt'),
      TextCellValue('Notater'),
    ]);
  }

  static void _appendExportRow(
    Sheet sheet, {
    required String facilityName,
    required String sectionName,
    required String tankName,
    required Object? fishCount,
    required Map<String, dynamic> logData,
  }) {
    sheet.appendRow([
      TextCellValue(facilityName),
      TextCellValue(sectionName),
      TextCellValue(tankName),
      _intCell(fishCount),
      TextCellValue(_formatDate(logData['date'])),
      _intCell(_firstValue([logData['mortality'], logData['dead']])),
      _doubleCell(_firstValue(
          [logData['feedKg'], logData['feed'], logData['feed_kg']])),
      _doubleCell(logData['temperature']),
      _doubleCell(_firstValue(
          [logData['avgWeight'], logData['weight'], logData['averageWeight']])),
      TextCellValue(
          _firstText([logData['note'], logData['notes'], logData['comment']])),
    ]);
  }

  static CellValue _intCell(Object? value) {
    final number = _toNum(value);
    if (number == null) return TextCellValue('');
    return IntCellValue(number.round());
  }

  static CellValue _doubleCell(Object? value) {
    final number = _toNum(value);
    if (number == null) return TextCellValue('');
    return DoubleCellValue(number.toDouble());
  }

  static CellValue _doubleOrText(double value, String fallback) {
    if (value <= 0 || !value.isFinite) return TextCellValue(fallback);
    return DoubleCellValue(value);
  }

  static num? _toNum(Object? value) {
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) {
      final cleaned = value.trim().replaceAll(',', '.');
      if (cleaned.isEmpty) return null;
      return num.tryParse(cleaned);
    }
    return null;
  }

  static String _formatDate(Object? value) {
    if (value == null) return '';
    if (value is Timestamp) return _dateFormat.format(value.toDate());
    if (value is DateTime) return _dateFormat.format(value);
    return value.toString();
  }

  static Object? _firstValue(List<Object?> values) {
    for (final value in values) {
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      return value;
    }
    return null;
  }

  static String _firstText(List<Object?> values) {
    final value = _firstValue(values);
    return value?.toString() ?? '';
  }

  static String _safeFileName(String value) {
    final cleaned = value.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    return cleaned.isEmpty ? 'fjellfisk' : cleaned;
  }

  static void _deleteDefaultSheet(Excel excel) {
    if (excel.sheets.containsKey('Sheet1') && excel.sheets.length > 1) {
      excel.delete('Sheet1');
    }
  }
}
