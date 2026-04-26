import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import '../providers/bluetooth_provider.dart';
import '../services/print_service.dart';

class QrCodeScreen extends StatefulWidget {
  const QrCodeScreen({super.key});

  @override
  State<QrCodeScreen> createState() => _QrCodeScreenState();
}

class _QrCodeScreenState extends State<QrCodeScreen> {
  final TextEditingController _controller = TextEditingController();
  String _qrData = "";

  Future<void> _printQr() async {
    if (_qrData.isEmpty) return;

    final btProvider = Provider.of<BluetoothProvider>(context, listen: false);
    if (!btProvider.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connect printer first')));
      return;
    }

    final printService = Provider.of<PrintService>(context, listen: false);
    
    // Generate QR Image
    final qrValidationResult = QrValidator.validate(
      data: _qrData,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.L,
    );

    if (qrValidationResult.status == QrValidationStatus.valid) {
      final qrCode = qrValidationResult.qrCode!;
      final painter = QrPainter.withQr(
        qr: qrCode,
        color: const Color(0xFF000000),
        gapless: true,
      );

      final picData = await painter.toImageData(300);
      if (picData != null) {
        final ticket = await printService.generateImageTicket(picData.buffer.asUint8List());
        btProvider.connection?.output.add(Uint8List.fromList(ticket));
        await btProvider.connection?.output.allSent;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate QR Code'),
        backgroundColor: const Color(0xFF1E2A5E),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Enter URL or Text',
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _qrData = val),
            ),
            const SizedBox(height: 24),
            if (_qrData.isNotEmpty)
              QrImageView(
                data: _qrData,
                version: QrVersions.auto,
                size: 200.0,
              ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _qrData.isEmpty ? null : _printQr,
              icon: const Icon(Icons.qr_code),
              label: const Text('Print QR Code'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
