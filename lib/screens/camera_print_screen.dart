import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:typed_data';
import '../providers/bluetooth_provider.dart';
import '../services/print_service.dart';

class CameraPrintScreen extends StatefulWidget {
  const CameraPrintScreen({super.key});

  @override
  State<CameraPrintScreen> createState() => _CameraPrintScreenState();
}

class _CameraPrintScreenState extends State<CameraPrintScreen> {
  CameraController? _controller;
  List<XFile> _capturedImages = [];
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _controller = CameraController(cameras[0], ResolutionPreset.medium);
    await _controller!.initialize();
    if (mounted) {
      setState(() => _isCameraInitialized = true);
    }
  }

  void _capture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final image = await _controller!.takePicture();
    setState(() => _capturedImages.add(image));
  }

  void _printBatch() async {
    if (_capturedImages.isEmpty) return;
    
    final btProvider = Provider.of<BluetoothProvider>(context, listen: false);
    if (!btProvider.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connect printer first')));
      return;
    }

    final printService = Provider.of<PrintService>(context, listen: false);
    
    for (var image in _capturedImages) {
      final bytes = await File(image.path).readAsBytes();
      final ticket = await printService.generateImageTicket(bytes);
      btProvider.connection?.output.add(Uint8List.fromList(ticket));
      await btProvider.connection?.output.allSent;
    }
    
    setState(() => _capturedImages.clear());
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture & Print'),
        backgroundColor: const Color(0xFF1E2A5E),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: CameraPreview(_controller!),
          ),
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('Captured: ${_capturedImages.length} images'),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    FloatingActionButton(
                      onPressed: _capture,
                      backgroundColor: const Color(0xFF1E2A5E),
                      child: const Icon(Icons.camera, color: Colors.white),
                    ),
                    if (_capturedImages.isNotEmpty)
                      ElevatedButton.icon(
                        onPressed: _printBatch,
                        icon: const Icon(Icons.print),
                        label: const Text('Print All'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.white),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
