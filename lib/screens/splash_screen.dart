import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/logging_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  final StorageService _storage = StorageService();
  final LoggingService _logger = LoggingService();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _controller.forward();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    _logger.log("App starting - Checking profile status for v8.5");
    
    // Give splash screen a moment to show
    await Future.delayed(const Duration(seconds: 3));
    
    try {
      final bool registered = await _storage.hasRegistered();
      
      _logger.log("Startup check: registered=$registered");

      if (!mounted) return;

      if (registered) {
        _logger.log("Profile detected - Navigating to Home");
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        _logger.log("No profile found - Navigating to Profile Setup");
        Navigator.pushReplacementNamed(context, '/profile');
      }
    } catch (e) {
      _logger.log("Critical error during startup: $e");
      if (mounted) Navigator.pushReplacementNamed(context, '/profile');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E2A5E),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.print, size: 100, color: Color(0xFFD4AF37)),
              const SizedBox(height: 24),
              const Text(
                'PANTAS PRINT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Smart Thermal Printer',
                style: TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 48),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
