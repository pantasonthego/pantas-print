import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import '../providers/bluetooth_provider.dart';
import '../services/print_service.dart';
import '../services/storage_service.dart';
import '../services/logging_service.dart';
import '../models/user_profile.dart';

class AirwayBillScreen extends StatefulWidget {
  const AirwayBillScreen({super.key});

  @override
  State<AirwayBillScreen> createState() => _AirwayBillScreenState();
}

class _AirwayBillScreenState extends State<AirwayBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _refController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  UserProfile? _myProfile;
  final StorageService _storage = StorageService();
  final LoggingService _logger = LoggingService();
  String _currentPaperSize = '58mm';
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final profile = await _storage.getProfile();
    final paperSize = await _storage.getPaperSize();
    setState(() {
      _myProfile = profile;
      _currentPaperSize = paperSize;
    });
  }

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    }
    controller?.resumeCamera();
  }

  void _scanRecipientQR() async {
    _logger.log("Opening Recipient QR Scanner");
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: QRView(
          key: qrKey,
          onQRViewCreated: (QRViewController controller) {
            this.controller = controller;
            controller.scannedDataStream.listen((scanData) {
              if (scanData.code != null) {
                Navigator.pop(context, scanData.code);
              }
            });
          },
        ),
      ),
    );

    if (result != null) {
      try {
        if (result.startsWith('PANTAS_PROFILE:')) {
          final parts = result.replaceFirst('PANTAS_PROFILE:', '').split('|');
          if (parts.length >= 3) {
            setState(() {
              _nameController.text = parts[1];
              _phoneController.text = parts[2];
              _logger.log("Recipient data auto-filled from QR: ${parts[0]}");
            });
          }
        }
      } catch (e) {
        _logger.log("Invalid QR scanned for recipient: $e");
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Profile QR Code')));
      }
    }
  }

  void _generateAndPrint() async {
    if (!_formKey.currentState!.validate()) return;
    if (_myProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please create your profile first')));
      return;
    }

    if (!_currentPaperSize.contains('A6')) {
      final proceed = await _showPaperSizeWarning();
      if (!proceed) return;
    }

    final airwayId = "PAN_AWB_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}_${_myProfile!.id.split('_').last}";
    
    final awbData = {
      'airway_id': airwayId,
      'type': 'secure_handover',
      'status': 'created',
      'sender_id': _myProfile!.id,
      'sender_name': _myProfile!.fullName,
      'recipient': {
        'name': _nameController.text.toUpperCase(),
        'phone': _phoneController.text,
        'address': _addressController.text.toUpperCase(),
      },
      'reference': _refController.text,
      'remarks': _remarksController.text,
      'created_at': DateTime.now().toIso8601String(),
    };

    await _storage.saveAirwayBill(awbData);
    _logger.log("Airway Bill created: $airwayId");

    _showPrintPreview(awbData);
  }

  Future<bool> _showPaperSizeWarning() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ WARNING', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
        content: Text('Current paper size: $_currentPaperSize\n\nFor AIRWAY BILL, please use 4" x 6" (A6) paper to ensure the best printing quality and proper QR code readability.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CHANGE SIZE')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('CONTINUE ANYWAY')),
        ],
      ),
    ) ?? false;
  }

  void _showPrintPreview(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Print Preview', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Paper Size:', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text(_currentPaperSize, style: const TextStyle(fontWeight: FontWeight.bold)),
              const Divider(),
              _previewRow('AWB ID', data['airway_id']),
              _previewRow('From', data['sender_name']),
              _previewRow('To', data['recipient']['name']),
              _previewRow('Address', data['recipient']['address']),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              _executePrint(data);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E2A5E), foregroundColor: Colors.white),
            child: const Text('PRINT NOW'),
          ),
        ],
      ),
    );
  }

  Widget _previewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _executePrint(Map<String, dynamic> data) async {
    final btProvider = Provider.of<BluetoothProvider>(context, listen: false);
    if (!btProvider.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Printer not connected. Saved to queue.')));
      return;
    }

    final printService = Provider.of<PrintService>(context, listen: false);
    _logger.log("Generating ESC/POS commands for AWB: ${data['airway_id']}");
    
    final ticket = await printService.generateTextTicket(
      "--------------------------------\n"
      "      AIRWAY BILL (A6)          \n"
      "      PANTAS PRINT              \n"
      "--------------------------------\n"
      "ID: ${data['airway_id']}\n"
      "FROM: ${data['sender_name']}\n"
      "TO: ${data['recipient']['name']}\n"
      "ADDR: ${data['recipient']['address']}\n"
      "REF: ${data['reference']}\n"
      "--------------------------------\n"
      "   [ SCAN FOR HANDOVER ]        \n"
      "--------------------------------\n"
    );

    btProvider.connection?.output.add(Uint8List.fromList(ticket));
    await btProvider.connection?.output.allSent;
    _logger.log("Print job completed successfully.");
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Printing Airway Bill...')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Airway Bill')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionHeader('Recipient Information', Icons.person_pin_circle),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _scanRecipientQR,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Recipient Profile QR'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            ),
            const SizedBox(height: 16),
            TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Recipient Name *', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'Required' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Recipient Phone', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextFormField(controller: _addressController, decoration: const InputDecoration(labelText: 'Recipient Address *', border: OutlineInputBorder()), maxLines: 3, validator: (v) => v!.isEmpty ? 'Required' : null),
            
            const SizedBox(height: 24),
            _buildSectionHeader('Additional Details', Icons.info_outline),
            const SizedBox(height: 12),
            TextFormField(controller: _refController, decoration: const InputDecoration(labelText: 'Reference / Quote #', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextFormField(controller: _remarksController, decoration: const InputDecoration(labelText: 'Remarks', border: OutlineInputBorder())),
            
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _generateAndPrint,
              icon: const Icon(Icons.print),
              label: const Text('GENERATE & PRINT AWB'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 60),
                backgroundColor: const Color(0xFF1E2A5E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF1E2A5E)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E2A5E))),
      ],
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
