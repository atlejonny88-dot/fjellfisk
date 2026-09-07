import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExcelDownloader {
  static Future<String?> download(Excel excel, String fileName) async {
    final bytes = excel.encode();
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Excel-filen ble ikke laget.');
    }

    final safeFileName = _safeFileName(fileName);

    if (Platform.isAndroid || Platform.isIOS) {
      final directory = await getTemporaryDirectory();
      final file =
          File('${directory.path}${Platform.pathSeparator}$safeFileName');
      await file.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: safeFileName,
        text: 'Excel eksport fra Fjellfisk',
      );

      if (kDebugMode) {
        debugPrint('Excel-fil delt: ${file.path}');
      }
      return file.path;
    }

    final directory = await _downloadDirectory();
    final file =
        File('${directory.path}${Platform.pathSeparator}$safeFileName');
    await file.writeAsBytes(bytes, flush: true);

    if (kDebugMode) {
      debugPrint('Excel-fil lagret: ${file.path}');
    }
    return file.path;
  }

  static Future<Directory> _downloadDirectory() async {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) return downloads;

    final documents = await getApplicationDocumentsDirectory();
    return documents;
  }

  static String _safeFileName(String fileName) {
    final cleaned = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    return cleaned.isEmpty ? 'fjellfisk.xlsx' : cleaned;
  }
}
