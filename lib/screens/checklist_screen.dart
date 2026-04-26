import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bluetooth_provider.dart';
import '../services/print_service.dart';

class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  final List<Map<String, dynamic>> _items = [];
  final TextEditingController _itemController = TextEditingController();

  void _addItem() {
    if (_itemController.text.isNotEmpty) {
      setState(() {
        _items.add({'text': _itemController.text, 'checked': false});
        _itemController.clear();
      });
    }
  }

  void _printChecklist() async {
    if (_items.isEmpty) return;
    
    final btProvider = Provider.of<BluetoothProvider>(context, listen: false);
    if (!btProvider.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connect printer first')));
      return;
    }

    final printService = Provider.of<PrintService>(context, listen: false);
    
    String content = "DAILY CHECKLIST\n" + "━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    for (var item in _items) {
      content += "□ ${item['text']}\n";
    }
    content += "━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    content += "- - - - - - - - - - - - - -";

    final ticket = await printService.generateTextTicket(content);
    btProvider.connection?.output.add(Uint8List.fromList(ticket));
    await btProvider.connection?.output.allSent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checklist Print'),
        backgroundColor: const Color(0xFF1E2A5E),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _itemController,
                    decoration: const InputDecoration(
                      hintText: 'Add item...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add_circle, color: Color(0xFF1E2A5E), size: 40),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(Icons.check_box_outline_blank),
                  title: Text(_items[index]['text']),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => setState(() => _items.removeAt(index)),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _printChecklist,
              icon: const Icon(Icons.print),
              label: const Text('Print Checklist'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
