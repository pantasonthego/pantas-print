import 'package:flutter/material.dart';

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Guide'),
        backgroundColor: const Color(0xFF1E2A5E),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStep(1, 'Connect to Bluetooth Printer', 'Ensure your thermal printer is turned on and paired in your phone settings. Then, click the "Connect" button on the home screen to select it.'),
          _buildStep(2, 'Print Text', 'Enter any text you want to print in the input box and press "Print Text". The app will automatically add a watermark and timestamp.'),
          _buildStep(3, 'Print Images', 'Select an image from your gallery or take a new photo using your camera. The app will automatically optimize it for thermal printing.'),
          _buildStep(4, 'Share from Other Apps', 'You can also share images or documents from other apps directly to PANTAS PRINT to start printing instantly.'),
        ],
      ),
    );
  }

  Widget _buildStep(int step, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFD4AF37),
            foregroundColor: Colors.white,
            child: Text(step.toString()),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(fontSize: 16, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
