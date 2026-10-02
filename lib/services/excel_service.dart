import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/production_report.dart';
import '../utils/data_values.dart';
import 'excel_downloader.dart';

class ExcelService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  static Future<String?> exportFacility({
    required String facilityId,
    required String facilityName,
    required AppLocalizations labels,
  }) async {
    final excel = Excel.createExcel();
    final sheetName = labels.excelSheetFacility;
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    _deleteDefaultSheet(excel);

    _appendHeader(sheet, labels);

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
    required AppLocalizations labels,
  }) async {
    final excel = Excel.createExcel();
    final sheetName = labels.excelSheetTank;
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    _deleteDefaultSheet(excel);

    _appendHeader(sheet, labels);

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
    required AppLocalizations labels,
  }) async {
    final excel = productionReportWorkbook(
      report: report,
      facilityName: facilityName,
      labels: labels,
    );
    final fileName =
        'produksjonsrapport_${_safeFileName(report.filterLabel)}_${DateFormat('yyyyMMdd').format(report.from)}_${DateFormat('yyyyMMdd').format(report.to)}.xlsx';
    return ExcelDownloader.download(excel, fileName);
  }

  static Excel productionReportWorkbook({
    required ProductionReport report,
    required String facilityName,
    AppLocalizations? labels,
  }) {
    final l10n = labels ?? lookupAppLocalizations(const Locale('nb'));
    final excel = Excel.createExcel();
    final summaryName = l10n.excelSheetSummary;
    final summary = excel[summaryName];
    final tanks = excel[l10n.excelSheetTankOverview];
    final logs = excel[l10n.excelSheetRegistrations];
    excel.setDefaultSheet(summaryName);
    _deleteDefaultSheet(excel);

    summary.appendRow([
      TextCellValue(l10n.productionReportTitle),
      TextCellValue(facilityName),
    ]);
    summary.appendRow([
      TextCellValue(l10n.period),
      TextCellValue('${_dateFormat.format(report.from)} - '
          '${_dateFormat.format(report.to)}'),
    ]);
    summary.appendRow([
      TextCellValue(l10n.filter),
      TextCellValue(report.filterLabel == 'Hele anlegget'
          ? l10n.entireFacility
          : report.filterLabel),
    ]);
    summary.appendRow([]);
    summary.appendRow([
      TextCellValue(l10n.keyFigures),
      TextCellValue(l10n.value),
    ]);
    summary.appendRow([
      TextCellValue(l10n.feedUsed),
      DoubleCellValue(report.feedKg),
    ]);
    summary.appendRow([
      TextCellValue(l10n.mortality),
      IntCellValue(report.mortality),
    ]);
    summary.appendRow([
      TextCellValue(l10n.registeredBiomassKg),
      DoubleCellValue(report.biomassKg),
    ]);
    summary.appendRow([
      TextCellValue(l10n.latestAverageWeightGram),
      _doubleOrText(report.latestAvgWeight, l10n.notEnoughData),
    ]);
    summary.appendRow([
      TextCellValue(l10n.weightChangeGram),
      report.weightChange == 0 || !report.weightChange.isFinite
          ? TextCellValue(l10n.notEnoughData)
          : DoubleCellValue(report.weightChange),
    ]);
    summary.appendRow([
      TextCellValue('FCR'),
      report.fcr == null
          ? TextCellValue(l10n.fcrUnavailable)
          : DoubleCellValue(report.fcr!),
    ]);
    summary.appendRow([
      TextCellValue(l10n.activeTanks),
      IntCellValue(report.activeTanks),
    ]);
    summary.appendRow([
      TextCellValue(l10n.emptyTanksLabel),
      IntCellValue(report.emptyTanks),
    ]);
    summary.appendRow([
      TextCellValue(l10n.registrations),
      IntCellValue(report.registrations),
    ]);
    summary.appendRow([
      TextCellValue(l10n.averageTemperatureLabel),
      report.avgTemperature == null
          ? TextCellValue(l10n.notEnoughData)
          : DoubleCellValue(report.avgTemperature!),
    ]);
    summary.appendRow([
      TextCellValue(l10n.minimumTemperatureLabel),
      report.minTemperature == null
          ? TextCellValue(l10n.notEnoughData)
          : DoubleCellValue(report.minTemperature!),
    ]);
    summary.appendRow([
      TextCellValue(l10n.maximumTemperatureLabel),
      report.maxTemperature == null
          ? TextCellValue(l10n.notEnoughData)
          : DoubleCellValue(report.maxTemperature!),
    ]);

    tanks.appendRow([
      TextCellValue(l10n.section),
      TextCellValue(l10n.tank),
      TextCellValue(l10n.fish),
      TextCellValue(l10n.averageWeight),
      TextCellValue(l10n.biomass),
      TextCellValue(l10n.feed),
      TextCellValue(l10n.mortality),
      TextCellValue('FCR'),
      TextCellValue(l10n.temperature),
    ]);
    for (final row in report.tanks) {
      tanks.appendRow([
        TextCellValue(row.sectionName),
        TextCellValue(row.tankName),
        IntCellValue(row.fishCount),
        _doubleOrText(row.latestWeight, l10n.notEnoughData),
        _doubleOrText(row.biomassKg, l10n.notEnoughData),
        DoubleCellValue(row.feedKg),
        IntCellValue(row.mortality),
        row.fcr == null
            ? TextCellValue(l10n.notEnoughData)
            : DoubleCellValue(row.fcr!),
        row.latestTemperature == null
            ? TextCellValue(l10n.notEnoughData)
            : DoubleCellValue(row.latestTemperature!),
      ]);
    }

    logs.appendRow([
      TextCellValue(l10n.date),
      TextCellValue(l10n.section),
      TextCellValue(l10n.tank),
      TextCellValue(l10n.mortality),
      TextCellValue(l10n.feed),
      TextCellValue(l10n.averageWeight),
      TextCellValue(l10n.temperature),
      TextCellValue(l10n.feedType),
      TextCellValue(l10n.pelletSize),
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

    return excel;
  }

  static void _appendHeader(Sheet sheet, AppLocalizations labels) {
    sheet.appendRow([
      TextCellValue(labels.facilityName),
      TextCellValue(labels.sectionBuilding),
      TextCellValue(labels.tank),
      TextCellValue(labels.numberOfFish),
      TextCellValue(labels.date),
      TextCellValue(labels.mortality),
      TextCellValue(labels.feedKg),
      TextCellValue(labels.temperature),
      TextCellValue(labels.averageWeight),
      TextCellValue(labels.notes),
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
      _doubleCell(
          DataValues.weight(logData) > 0 ? DataValues.weight(logData) : null),
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
    if (value is num) return value.isFinite ? value : null;
    if (value is String) {
      final cleaned = value.trim().replaceAll(',', '.');
      if (cleaned.isEmpty) return null;
      final parsed = num.tryParse(cleaned);
      return parsed != null && parsed.isFinite ? parsed : null;
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
