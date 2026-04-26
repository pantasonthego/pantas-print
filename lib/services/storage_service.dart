import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/user_profile.dart';
import 'logging_service.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final LoggingService _logger = LoggingService();

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/PANTAS_PRINT';
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    final subDirs = ['profiles', 'airway', 'history', 'schedules', 'logs', 'settings'];
    for (var sub in subDirs) {
      final subDir = Directory('$path/$sub');
      if (!await subDir.exists()) {
        await subDir.create(recursive: true);
      }
    }
    
    return path;
  }

  // --- PROFILE MANAGEMENT (Simplified for v8.5) ---

  Future<void> saveProfile(UserProfile profile) async {
    try {
      final path = await _localPath;
      final file = File('$path/profiles/user_profile.json');
      await file.writeAsString(json.encode(profile.toJson()));
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_registered', true);
      _logger.log("Profile saved successfully to ${file.path}");
    } catch (e) {
      _logger.log("Error saving profile: $e");
    }
  }

  Future<UserProfile?> getProfile() async {
    try {
      final path = await _localPath;
      final file = File('$path/profiles/user_profile.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        return UserProfile.fromJson(json.decode(content));
      }
    } catch (e) {
      _logger.log("Error reading profile: $e");
    }
    return null;
  }

  Future<bool> hasRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('has_registered') == true) return true;
    
    final path = await _localPath;
    final file = File('$path/profiles/user_profile.json');
    return await file.exists();
  }

  // Compatibility method for existing screens
  Future<Map<String, dynamic>?> getUserData() async {
    final profile = await getProfile();
    if (profile != null) {
      return {
        'profile': profile.toJson(),
        'user_id': profile.id,
      };
    }
    return null;
  }

  // --- SETTINGS & PAPER SIZE ---

  Future<void> savePaperSize(String size) async {
    try {
      final path = await _localPath;
      final file = File('$path/settings/paper_settings.json');
      await file.writeAsString(json.encode({'paper_size': size}));
    } catch (e) {
      _logger.log("Error saving paper size: $e");
    }
  }

  Future<String> getPaperSize() async {
    try {
      final path = await _localPath;
      final file = File('$path/settings/paper_settings.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        return json.decode(content)['paper_size'] ?? '58mm';
      }
    } catch (e) {
      _logger.log("Error reading paper size: $e");
    }
    return '58mm';
  }

  // --- TRANSACTIONS & AIRWAY BILLS ---

  Future<void> saveAirwayBill(Map<String, dynamic> data) async {
    try {
      final path = await _localPath;
      final id = data['airway_id'];
      final file = File('$path/airway/$id.json');
      await file.writeAsString(json.encode(data));
      _logger.log("Airway Bill saved: $id");
    } catch (e) {
      _logger.log("Error saving AWB: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getAllTransactions() async {
    try {
      final path = await _localPath;
      final dir = Directory('$path/airway');
      if (!await dir.exists()) return [];
      
      final List<Map<String, dynamic>> transactions = [];
      final files = dir.listSync();
      for (var file in files) {
        if (file is File && file.path.endsWith('.json')) {
          final content = await file.readAsString();
          transactions.add(json.decode(content));
        }
      }
      transactions.sort((a, b) => b['created_at'].compareTo(a['created_at']));
      return transactions;
    } catch (e) {
      _logger.log("Error reading transactions: $e");
    }
    return [];
  }

  Future<void> updateAwbStatus(String id, String statusKey, String statusValue) async {
    try {
      final path = await _localPath;
      final file = File('$path/airway/$id.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final Map<String, dynamic> data = json.decode(content);
        data[statusKey] = statusValue;
        data['last_updated'] = DateTime.now().toIso8601String();
        await file.writeAsString(json.encode(data));
      }
    } catch (e) {
      _logger.log("Error updating AWB status: $e");
    }
  }

  // --- HISTORY MANAGEMENT ---

  Future<void> saveHistory(Map<String, dynamic> data) async {
    try {
      final path = await _localPath;
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final id = DateTime.now().millisecondsSinceEpoch;
      final file = File('$path/history/${date}_$id.json');
      await file.writeAsString(json.encode(data));
    } catch (e) {
      _logger.log("Error saving history: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getHistory(DateTime date) async {
    try {
      final path = await _localPath;
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final dir = Directory('$path/history');
      if (!await dir.exists()) return [];
      
      final List<Map<String, dynamic>> history = [];
      final files = dir.listSync();
      for (var file in files) {
        if (file is File && file.path.contains(dateStr)) {
          final content = await file.readAsString();
          history.add(json.decode(content));
        }
      }
      return history;
    } catch (e) {
      _logger.log("Error reading history: $e");
    }
    return [];
  }

  // --- SCHEDULE MANAGEMENT ---

  Future<void> saveSchedule(Map<String, dynamic> schedule) async {
    try {
      final path = await _localPath;
      final id = schedule['id'];
      final file = File('$path/schedules/$id.json');
      await file.writeAsString(json.encode(schedule));
    } catch (e) {
      _logger.log("Error saving schedule: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getSchedules() async {
    try {
      final path = await _localPath;
      final dir = Directory('$path/schedules');
      if (!await dir.exists()) return [];
      
      final List<Map<String, dynamic>> schedules = [];
      final files = dir.listSync();
      for (var file in files) {
        if (file is File && file.path.endsWith('.json')) {
          final content = await file.readAsString();
          schedules.add(json.decode(content));
        }
      }
      return schedules;
    } catch (e) {
      _logger.log("Error reading schedules: $e");
    }
    return [];
  }

  Future<void> deleteSchedule(String id) async {
    try {
      final path = await _localPath;
      final file = File('$path/schedules/$id.json');
      if (await file.exists()) await file.delete();
    } catch (e) {
      _logger.log("Error deleting schedule: $e");
    }
  }
}
