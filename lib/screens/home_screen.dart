import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../providers/bluetooth_provider.dart';
import '../services/print_service.dart';
import '../services/logging_service.dart';
import '../services/storage_service.dart';
import '../models/user_profile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LoggingService _logger = LoggingService();
  final StorageService _storage = StorageService();
  UserProfile? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _logger.log("HomeScreen accessed");
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _storage.getProfile();
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
      if (profile != null) {
        _logger.log("Profile loaded successfully for: ${profile.name}");
      } else {
        _logger.log("No profile found in storage");
      }
    } catch (e) {
      _logger.log("Error loading profile: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final btProvider = Provider.of<BluetoothProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PANTAS PRINT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            Text('Smart Thermal Printer', style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.8))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () => Navigator.pushNamed(context, '/profile').then((_) => _loadProfile()),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings').then((_) => _loadProfile()),
          ),
        ],
      ),
      body: Container(
        color: Colors.grey[100],
        child: Column(
          children: [
            _buildStatusHeader(btProvider),
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_profile == null)
              _buildProfileWarning()
            else
              Expanded(
                child: GridView.count(
                  padding: const EdgeInsets.all(16),
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: [
                    _buildMenuCard(context, 'Airway Bill', Icons.local_shipping, '/airway', Colors.orange),
                    _buildMenuCard(context, 'Transactions', Icons.receipt_long, '/transactions', Colors.teal),
                    _buildMenuCard(context, 'OCR Scan', Icons.document_scanner, '/ocr', Colors.green),
                    _buildMenuCard(context, 'QR Code', Icons.qr_code, '/qr', Colors.purple),
                    _buildMenuCard(context, 'Checklist', Icons.checklist, '/checklist', Colors.blue),
                    _buildMenuCard(context, 'Capture & Print', Icons.camera_alt, '/camera', Colors.red),
                    _buildMenuCard(context, 'History & Queue', Icons.history, '/history', Colors.blueGrey),
                    _buildMenuCard(context, 'Pick PDF', Icons.picture_as_pdf, null, Colors.redAccent, onTap: () => _pickAndPrintPdf(context)),
                    _buildMenuCard(context, 'Schedule Print', Icons.calendar_month, '/schedule', Colors.indigo),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileWarning() {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              const Text('Profile Not Found', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('The app could not find your registered profile data. Please ensure you have signed up or try creating your profile again.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/profile').then((_) => _loadProfile()),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E2A5E), foregroundColor: Colors.white, minimumSize: const Size(200, 50)),
                child: const Text('Go to Profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusHeader(BluetoothProvider btProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E2A5E),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Icon(
            btProvider.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
            color: btProvider.isConnected ? Colors.greenAccent : Colors.white54,
            size: 40,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(btProvider.isConnected ? 'Connected to:' : 'No Printer Connected', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text(btProvider.isConnected ? btProvider.connectedDevice!.name ?? 'Unknown Device' : 'Tap to scan for printers', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _showDeviceSelection(context, btProvider),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
            child: Text(btProvider.isConnected ? 'Change' : 'Scan'),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, IconData icon, String? route, Color color, {VoidCallback? onTap}) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: () {
          _logger.log("Accessed Menu: $title");
          if (onTap != null) {
            onTap();
          } else {
            Navigator.pushNamed(context, route!);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  void _showDeviceSelection(BuildContext context, BluetoothProvider btProvider) {
    btProvider.scanDevices();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Consumer<BluetoothProvider>(
          builder: (context, provider, child) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Select Bluetooth Printer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  if (provider.isScanning)
                    const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                  else if (provider.devices.isEmpty)
                    const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No bonded devices found.')))
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: provider.devices.length,
                        itemBuilder: (context, index) {
                          final device = provider.devices[index];
                          return ListTile(
                            leading: const Icon(Icons.print, color: Color(0xFF1E2A5E)),
                            title: Text(device.name ?? 'Unknown'),
                            subtitle: Text(device.address),
                            onTap: () async {
                              Navigator.pop(context);
                              await provider.connect(device);
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickAndPrintPdf(BuildContext context) async {
    final btProvider = Provider.of<BluetoothProvider>(context, listen: false);
    if (!btProvider.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connect printer first')));
      return;
    }

    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result != null) {
      final filePath = result.files.single.path!;
      final printService = Provider.of<PrintService>(context, listen: false);
      final ticket = await printService.generatePdfTicket(filePath);
      btProvider.connection?.output.add(Uint8List.fromList(ticket));
      await btProvider.connection?.output.allSent;
    }
  }
}
