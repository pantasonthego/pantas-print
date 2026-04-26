import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/logging_service.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final TextEditingController _textController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _recurring = 'None';
  final List<String> _recurringOptions = ['None', 'Daily', 'Weekly', 'Monthly'];
  List<Map<String, dynamic>> _schedules = [];
  final LoggingService _logger = LoggingService();

  @override
  void initState() {
    super.initState();
    _loadSchedules();
    _logger.log("Opened Schedule Screen");
  }

  Future<void> _loadSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final String? schedulesJson = prefs.getString('print_schedules');
    if (schedulesJson != null) {
      setState(() {
        _schedules = List<Map<String, dynamic>>.from(json.decode(schedulesJson));
      });
      _logger.log("Loaded ${_schedules.length} schedules from storage");
    }
  }

  Future<void> _saveSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('print_schedules', json.encode(_schedules));
  }

  void _addSchedule() {
    if (_textController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter text to print')));
      return;
    }

    final scheduleDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    setState(() {
      _schedules.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'text': _textController.text,
        'time': scheduleDateTime.toIso8601String(),
        'recurring': _recurring,
        'status': 'Pending',
      });
      _textController.clear();
      _recurring = 'None';
    });
    _saveSchedules();
    _logger.log("Added new schedule: ${scheduleDateTime.toIso8601String()}");
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Schedule added successfully')));
  }

  void _deleteSchedule(int index) {
    final deleted = _schedules[index];
    setState(() {
      _schedules.removeAt(index);
    });
    _saveSchedules();
    _logger.log("Deleted schedule: ${deleted['text']}");
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _selectedTime);
    if (picked != null) setState(() => _selectedTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheduled Print'),
        backgroundColor: const Color(0xFF1E2A5E),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Set New Print Schedule', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E2A5E))),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _textController,
                        decoration: const InputDecoration(
                          labelText: 'Text to Print',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.text_fields),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Date', style: TextStyle(fontSize: 12)),
                              subtitle: Text(DateFormat('yyyy-MM-dd').format(_selectedDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                              trailing: const Icon(Icons.calendar_today, size: 20),
                              onTap: _pickDate,
                            ),
                          ),
                          const VerticalDivider(),
                          Expanded(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Time', style: TextStyle(fontSize: 12)),
                              subtitle: Text(_selectedTime.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
                              trailing: const Icon(Icons.access_time, size: 20),
                              onTap: _pickTime,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _recurring,
                        items: _recurringOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
                        onChanged: (val) => setState(() => _recurring = val!),
                        decoration: const InputDecoration(
                          labelText: 'Recurring Option',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.repeat),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _addSchedule,
                        icon: const Icon(Icons.save),
                        label: const Text('Save Schedule'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: const Color(0xFF1E2A5E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Divider(thickness: 1, height: 1),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: Colors.grey[100],
            child: const Text('UPCOMING SCHEDULES', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1)),
          ),
          Expanded(
            flex: 5,
            child: _schedules.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_note, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text('No schedules found', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _schedules.length,
                    itemBuilder: (context, index) {
                      final item = _schedules[index];
                      final dateTime = DateTime.parse(item['time']);
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        elevation: 2,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF1E2A5E).withOpacity(0.1),
                            child: const Icon(Icons.print, color: Color(0xFF1E2A5E), size: 20),
                          ),
                          title: Text(item['text'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            "${DateFormat('MMM dd, yyyy - HH:mm').format(dateTime)} (${item['recurring']})",
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () => _deleteSchedule(index),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
