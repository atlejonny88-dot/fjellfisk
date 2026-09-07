// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import 'package:excel/excel.dart';

class ExcelDownloader {
  static Future<String?> download(Excel excel, String fileName) async {
    final bytes = excel.encode();
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Excel-filen ble ikke laget.');
    }

    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none';

    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);

    return fileName;
  }
}
