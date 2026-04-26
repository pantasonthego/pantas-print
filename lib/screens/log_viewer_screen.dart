import 'package:flutter/material.dart';
import '../services/logging_service.dart';

class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key});

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  String _logs = "Loading logs...";
  final LoggingService _loggingService = LoggingService();

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final logs = await _loggingService.readLogs();
    setState(() {
      _logs = logs;
    });
  }

  Future<void> _clearLogs() async {
    await _loggingService.clearLogs();
    _loadLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Logs'),
        backgroundColor: const Color(0xFF1E2A5E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _loggingService.shareLogs(),
            tooltip: 'Share Logs',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _clearLogs,
            tooltip: 'Clear Logs',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(16.0),
        width: double.infinity,
        color: Colors.black87,
        child: SingleChildScrollView(
          child: SelectableText(
            _logs,
            style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ),
    );
  }
}
