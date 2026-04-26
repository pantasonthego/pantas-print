import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import '../services/storage_service.dart';
import '../services/logging_service.dart';
import '../services/print_service.dart';
import '../providers/bluetooth_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final StorageService _storage = StorageService();
  final LoggingService _logger = LoggingService();
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final history = await _storage.getHistory(_selectedDate);
    setState(() {
      _history = history;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History & Queue'),
        backgroundColor: const Color(0xFF1E2A5E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
                _loadHistory();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDateHeader(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _history.isEmpty 
                ? _buildEmptyState()
                : _buildHistoryList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[200],
      width: double.infinity,
      child: Text(
        "Showing records for: ${DateFormat('EEEE, MMM d, yyyy').format(_selectedDate)}",
        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E2A5E)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('No records found for this date.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final item = _history[index];
        final isAWB = item['type'] == 'secure_handover';
        
        return Card(
          child: ListTile(
            leading: Icon(isAWB ? Icons.local_shipping : Icons.print, color: const Color(0xFF1E2A5E)),
            title: Text(item['recipient']?['name'] ?? 'General Print'),
            subtitle: Text(item['airway_id'] ?? 'ID: Unknown'),
            trailing: IconButton(
              icon: const Icon(Icons.print_outlined),
              onPressed: () => _reprint(item),
            ),
            onTap: () => _showDetails(item),
          ),
        );
      },
    );
  }

  void _showDetails(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item['airway_id'] ?? 'Print Details', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            _detailRow('Recipient', item['recipient']?['name']),
            _detailRow('Phone', item['recipient']?['phone']),
            _detailRow('Address', item['recipient']?['address']),
            _detailRow('Status', item['status']?.toUpperCase(), isStatus: true),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _reprint(item);
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: const Color(0xFF1E2A5E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('REPRINT NOW'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String? value, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12))),
          Text(value ?? '-', style: TextStyle(fontWeight: FontWeight.bold, color: isStatus ? Colors.green : Colors.black87)),
        ],
      ),
    );
  }

  void _reprint(Map<String, dynamic> item) async {
    final btProvider = Provider.of<BluetoothProvider>(context, listen: false);
    if (!btProvider.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Printer not connected')));
      return;
    }

    final printService = Provider.of<PrintService>(context, listen: false);
    final isAWB = item['type'] == 'secure_handover';
    _logger.log("Reprinting ${isAWB ? 'AWB' : 'Item'}: ${item['id'] ?? item['airway_id']}");
    
    List<int> ticket;
    if (isAWB) {
      ticket = await printService.generateAwbTicket(item);
    } else if (item['type'] == 'text_print') {
      ticket = await printService.generateTextTicket(item['content'] ?? '', saveHistory: false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reprint not supported for this type yet.')));
      return;
    }

    btProvider.connection?.output.add(Uint8List.fromList(ticket));
    await btProvider.connection?.output.allSent;
    _logger.log("Reprint successful.");
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reprinting...')));
  }
}
