import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'logging_service.dart';

class BackupService {
  final LoggingService _logger = LoggingService();

  Future<String?> exportBackup() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final pantasDir = Directory('${appDir.path}/PANTAS_PRINT');
      
      if (!pantasDir.existsSync()) {
        _logger.log("Backup failed: No data directory found.");
        return null;
      }

      final backupPath = '${appDir.path}/PANTAS_BACKUP_${DateTime.now().millisecondsSinceEpoch}.zip';
      final encoder = ZipFileEncoder();
      encoder.create(backupPath);
      encoder.addDirectory(pantasDir);
      encoder.close();

      _logger.log("Backup created successfully at $backupPath");
      await Share.shareXFiles([XFile(backupPath)], text: 'PANTAS PRINT Data Backup');
      return backupPath;
    } catch (e) {
      _logger.log("Error creating backup: $e");
      return null;
    }
  }

  Future<bool> importBackup() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null || result.files.single.path == null) return false;
      
      final zipPath = result.files.single.path!;
      final appDir = await getApplicationDocumentsDirectory();
      final pantasDir = Directory('${appDir.path}/PANTAS_PRINT');
      
      // Clean current data
      if (pantasDir.existsSync()) {
        pantasDir.deleteSync(recursive: true);
      }
      pantasDir.createSync(recursive: true);

      final bytes = File(zipPath).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          File('${appDir.path}/$filename')
            ..createSync(recursive: true)
            ..writeAsBytesSync(data);
        } else {
          Directory('${appDir.path}/$filename').createSync(recursive: true);
        }
      }

      _logger.log("Backup restored successfully from $zipPath");
      return true;
    } catch (e) {
      _logger.log("Error restoring backup: $e");
      return false;
    }
  }
}
