import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import '../services/storage_service.dart';
import '../services/logging_service.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final StorageService _storage = StorageService();
  final LoggingService _logger = LoggingService();
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    final data = await _storage.getAllTransactions();
    setState(() {
      _transactions = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        backgroundColor: const Color(0xFF1E2A5E),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transactions.isEmpty
              ? _buildEmptyState()
              : _buildTransactionList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('No transactions recorded.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final item = _transactions[index];
        final senderStatus = item['sender_status'] ?? 'Not Submitted';
        final recipientStatus = item['recipient_status'] ?? 'Not Received';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: Icon(Icons.local_shipping, color: senderStatus == 'Submitted' ? Colors.green : Colors.orange),
            title: Text(item['recipient']?['name'] ?? 'Unknown Recipient'),
            subtitle: Text('ID: ${item['airway_id']}'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _statusRow('Sender Status', senderStatus),
                    _statusRow('Recipient Status', recipientStatus),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _scanForUpdate(item['airway_id'], 'sender_status', 'Submitted'),
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text('Handover'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E2A5E), 
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _scanForUpdate(item['airway_id'], 'recipient_status', 'Received'),
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Receive'),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusRow(String label, String value) {
    final isDone = value == 'Submitted' || value == 'Received';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: isDone ? Colors.green : Colors.orange)),
        ],
      ),
    );
  }

  void _scanForUpdate(String airwayId, String key, String value) async {
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
      await _storage.updateAwbStatus(airwayId, key, value);
      _logger.log("Transaction $airwayId updated: $key -> $value");
      _loadTransactions();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status updated to $value')));
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
