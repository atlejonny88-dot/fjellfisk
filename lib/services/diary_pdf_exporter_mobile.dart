import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class DiaryPdfExporter {
  static Future<String?> export(Uint8List bytes, String fileName) async {
    if (bytes.isEmpty) throw Exception('PDF-filen ble ikke laget.');
    final safeFileName = _safeFileName(fileName);

    if (Platform.isAndroid || Platform.isIOS) {
      final directory = await getTemporaryDirectory();
      final file =
          File('${directory.path}${Platform.pathSeparator}$safeFileName');
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: safeFileName,
        text: 'Dagbok / Driftslogg fra Fjellfisk',
      );
      return file.path;
    }

    final directory = await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final file =
        File('${directory.path}${Platform.pathSeparator}$safeFileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static String _safeFileName(String fileName) {
    final cleaned = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    return cleaned.isEmpty ? 'fjellfisk_dagbok.pdf' : cleaned;
  }
}
