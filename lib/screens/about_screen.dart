import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About Developer'),
        backgroundColor: const Color(0xFF1E2A5E),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Mohd Jany bin Mustapha',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'pantasonthego@gmail.com',
                style: TextStyle(fontSize: 18, color: Color(0xFF1E2A5E), fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              const Card(
                elevation: 2,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.calendar_today, color: Color(0xFFD4AF37)),
                        title: Text('Developed in 2026'),
                      ),
                      ListTile(
                        leading: Icon(Icons.group, color: Color(0xFFD4AF37)),
                        title: Text('For Kumpulan PANTAS'),
                      ),
                      ListTile(
                        leading: Icon(Icons.verified_user_outlined, color: Color(0xFFD4AF37)),
                        title: Text('Version 1.0.0'),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              const Text(
                'PANTAS PRINT - Futuristic Thermal Printing',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
