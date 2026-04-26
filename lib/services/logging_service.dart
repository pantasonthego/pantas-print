import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class LoggingService {
  static final LoggingService _instance = LoggingService._internal();
  factory LoggingService() => _instance;
  LoggingService._internal();

  Future<File> get _logFile async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/PANTAS_PRINT/logs';
    final dir = Directory(path);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return File('$path/activity_log.txt');
  }

  Future<void> log(String message) async {
    final file = await _logFile;
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final logEntry = '[$timestamp] $message\n';
    await file.writeAsString(logEntry, mode: FileMode.append);
    print(logEntry);
  }

  Future<String> readLogs() async {
    try {
      final file = await _logFile;
      if (await file.exists()) {
        return await file.readAsString();
      }
      return "No logs available yet.";
    } catch (e) {
      return "Error reading logs: $e";
    }
  }

  Future<void> clearLogs() async {
    final file = await _logFile;
    if (await file.exists()) {
      await file.writeAsString("");
    }
  }

  Future<void> shareLogs() async {
    final file = await _logFile;
    if (await file.exists()) {
      await Share.shareXFiles([XFile(file.path)], text: 'PANTAS PRINT Activity Logs');
    }
  }
}
