import 'dart:io';

import 'package:chest/util/helpers/answers.dart';
import 'package:path_provider/path_provider.dart';

class AuxiliarFunctions {
  static void downloadAnswerWeb(Answer answer, {String titlePage = 'CHEST'}) {}
  // TODO
  static String getIdUser() => "";

  static Future<String> get _localPath async {
    final directory = await getApplicationCacheDirectory();
    return directory.path;
  }

  static Future<File> _localFile(localFileName) async {
    final path = await _localPath;
    return File('$path/$localFileName');
  }

  static Future<bool> writeFile(
      {required String fileName,
      required String toFile,
      FileMode mode = FileMode.write}) async {
    final file = await _localFile(fileName);
    final File f = await file.writeAsString(toFile, mode: mode);
    return await f.exists();
  }

  static Future<String?> readFile({required String fileName}) async {
    try {
      final file = await _localFile(fileName);
      final data = await file.readAsString();
      return data;
    } catch (error) {
      return null;
    }
  }
}
