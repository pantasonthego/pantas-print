import 'dart:io';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../services/storage_service.dart';
import '../services/logging_service.dart';
import '../services/backup_service.dart';
import 'log_viewer_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StorageService _storage = StorageService();
  final LoggingService _logger = LoggingService();
  final BackupService _backup = BackupService();
  
  String _selectedSize = '58mm x 30mm';
  Map<String, String> _deviceInfo = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final size = await _storage.getPaperSize();
    final info = await _getDeviceInfo();
    setState(() {
      _selectedSize = size;
      _deviceInfo = info;
      _isLoading = false;
    });
  }

  Future<Map<String, String>> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return {
        'MODEL': androidInfo.model,
        'BRAND': androidInfo.brand.toUpperCase(),
        'OS': 'Android ${androidInfo.version.release} (API ${androidInfo.version.sdkInt})',
        'HARDWARE': androidInfo.hardware,
      };
    }
    return {'MODEL': 'Unknown', 'BRAND': 'Unknown', 'OS': 'Unknown', 'HARDWARE': 'Unknown'};
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Settings'),
        backgroundColor: const Color(0xFF1E2A5E),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('PRINTER CONFIGURATION'),
          _buildCard([
            ListTile(
              title: const Text('Paper Size'),
              subtitle: Text(_selectedSize),
              leading: const Icon(Icons.straighten, color: Color(0xFF1E2A5E)),
              onTap: _showPaperSizePicker,
            ),
          ]),

          _buildSectionHeader('DIAGNOSTICS & LOGS'),
          _buildCard([
            ListTile(
              title: const Text('Activity Logs'),
              subtitle: const Text('View and share app behavior logs'),
              leading: const Icon(Icons.history_edu, color: Color(0xFF1E2A5E)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                _logger.log("User accessed Activity Logs from Settings");
                Navigator.push(context, MaterialPageRoute(builder: (context) => const LogViewerScreen()));
              },
            ),
          ]),

          _buildSectionHeader('MINIMUM SYSTEM REQUIREMENT'),
          _buildCard([
            const ListTile(
              title: Text('Android 10 (API 29) or higher'),
              subtitle: Text('Bluetooth 4.0+, 2GB RAM, 100MB Storage'),
              leading: Icon(Icons.check_circle_outline, color: Colors.green),
            ),
          ]),

          _buildSectionHeader('DEVICE & CONFIGURATION'),
          _buildCard([
            _infoTile('MODEL', _deviceInfo['MODEL']),
            _infoTile('BRAND', _deviceInfo['BRAND']),
            _infoTile('OS', _deviceInfo['OS']),
            _infoTile('HARDWARE', _deviceInfo['HARDWARE']),
          ]),

          _buildSectionHeader('STORAGE & BACKUP'),
          _buildCard([
            const ListTile(
              title: Text('Storage Location'),
              subtitle: Text('Internal Storage > PANTAS_PRINT'),
              leading: Icon(Icons.folder_open, color: Color(0xFF1E2A5E)),
            ),
            const Divider(height: 1),
            ListTile(
              title: const Text('Backup Data'),
              subtitle: const Text('Export Profile, AWB, History & Schedules'),
              leading: const Icon(Icons.backup_outlined, color: Colors.blue),
              onTap: () async {
                final path = await _backup.exportBackup();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup saved to: $path')));
              },
            ),
            const Divider(height: 1),
            ListTile(
              title: const Text('Restore Data'),
              subtitle: const Text('Import from a previous backup ZIP'),
              leading: const Icon(Icons.restore, color: Colors.orange),
              onTap: () => _showRestoreWarning(),
            ),
          ]),

          _buildSectionHeader('LICENSE'),
          _buildCard([
            const ListTile(
              title: Text('Professional Global Edition'),
              subtitle: Text('Enterprise Grade Printing Protocol'),
              leading: Icon(Icons.verified_user, color: Color(0xFFD4AF37)),
            ),
          ]),

          _buildSectionHeader('CORE CAPABILITIES'),
          _buildCard([
            _bulletPoint('Smart Thermal Printing (ESC/POS)'),
            _bulletPoint('PDF & Image Auto-Fit Engine'),
            _bulletPoint('Secure Handover AWB Protocol'),
            _bulletPoint('Offline-First Data Architecture'),
            _bulletPoint('OCR Document Recognition'),
            _bulletPoint('QR Code Profile & Generator'),
            _bulletPoint('Scheduled Batch Printing'),
            _bulletPoint('Activity Behavior Logging'),
            _bulletPoint('Multi-Size Roll Support'),
            _bulletPoint('Offline Queue Management'),
            _bulletPoint('Professional vCard Export'),
          ]),

          _buildSectionHeader('TECHNICAL DOCUMENTATION'),
          _buildCard([
            const ListTile(
              title: Text('OPERATIONAL GUIDE'),
              subtitle: Text('1. Connect Bluetooth Printer\n2. Setup User Profile\n3. Choose Module (PDF/AWB/OCR)\n4. Preview & Print'),
            ),
            const Divider(),
            const ListTile(
              title: Text('SPECIALIZED APPLICATION'),
              subtitle: Text('Uses Offline Native Protocol for zero cloud dependency. Secure Handover ensures 2-way proof of delivery via local QR validation.'),
            ),
          ]),

          _buildSectionHeader('LEGAL & PRIVACY'),
          _buildCard([
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'OFFLINE NATIVE PROTOCOL: This application operates with zero cloud dependency. No personal data, imagery, or metadata is transmitted externally. All processing is executed on-device. Users assume full responsibility for procedural outcomes and data management.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ]),

          _buildSectionHeader('DEVELOPER DETAILS'),
          _buildCard([
            const ListTile(
              title: Text('Mohd Jany bin Mustapha'),
              subtitle: Text('Lead Developer @ 2026'),
              leading: Icon(Icons.code),
            ),
            const Divider(height: 1),
            const ListTile(
              title: Text('pantasonthego@gmail.com'),
              leading: Icon(Icons.email_outlined),
            ),
            const Divider(height: 1),
            const ListTile(
              title: Text('+60132448330'),
              leading: Icon(Icons.phone_android),
            ),
          ]),

          const SizedBox(height: 40),
          const Center(
            child: Text(
              'PANTAS PRINT - Smart Thermal Printer\nv8.5 Professional',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF1E2A5E), fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 24),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 11, letterSpacing: 1.2)),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(children: children),
    );
  }

  Widget _infoTile(String label, String? value) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: Text(value ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _bulletPoint(String text) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.arrow_right, size: 18),
      title: Text(text, style: const TextStyle(fontSize: 13)),
    );
  }

  void _showPaperSizePicker() {
    final List<String> sizes = ['58mm x 30mm', '58mm x 40mm', '80mm x 60mm/80mm', '100mm x 100mm', '100mm x 150mm (A6)'];
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: sizes.map((s) => ListTile(
          title: Text(s),
          onTap: () async {
            await _storage.savePaperSize(s);
            setState(() => _selectedSize = s);
            Navigator.pop(context);
          },
        )).toList(),
      ),
    );
  }

  void _showRestoreWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('RESTORE DATA'),
        content: const Text('Restoring will OVERWRITE all current data (Profile, AWB, History). This action cannot be undone. Do you want to proceed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(onPressed: () async {
            final success = await _backup.importBackup();
            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? 'Restore successful!' : 'Restore failed.')));
            }
          }, child: const Text('PROCEED')),
        ],
      ),
    );
  }
}
