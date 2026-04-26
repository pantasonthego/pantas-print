import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../services/logging_service.dart';
import '../models/user_profile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final StorageService _storage = StorageService();
  final LoggingService _logger = LoggingService();
  
  bool _isLoading = true;
  bool _isFirstTime = true;
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _deptController = TextEditingController();
  
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final profile = await _storage.getProfile();
    if (profile != null) {
      setState(() {
        _profile = profile;
        _nameController.text = profile.fullName;
        _emailController.text = profile.email;
        _phoneController.text = profile.phone;
        _deptController.text = profile.department;
        _isFirstTime = false;
      });
      _logger.log("Profile loaded for: ${profile.fullName}");
    } else {
      setState(() {
        _isFirstTime = true;
      });
      _logger.log("No profile found. First-time setup.");
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    final newProfile = UserProfile(
      id: _profile?.id ?? "PANTAS_${DateTime.now().millisecondsSinceEpoch}",
      fullName: _nameController.text,
      email: _emailController.text,
      phone: _phoneController.text,
      department: _deptController.text,
      createdAt: _profile?.createdAt ?? DateTime.now(),
    );

    await _storage.saveProfile(newProfile);
    _logger.log("Profile updated: ${newProfile.fullName}");
    
    setState(() {
      _profile = newProfile;
      _isFirstTime = false;
    });
    
    setState(() => _isLoading = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved successfully!')),
    );
  }

  void _exportVCard() {
    if (_profile == null) return;
    final vcard = "BEGIN:VCARD\nVERSION:3.0\nFN:${_profile!.fullName}\nEMAIL:${_profile!.email}\nTEL:${_profile!.phone}\nORG:${_profile!.department}\nEND:VCARD";
    Share.share(vcard, subject: 'My PANTAS Contact');
    _logger.log("Exported vCard for ${_profile!.fullName}");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Profile'),
        backgroundColor: const Color(0xFF1E2A5E),
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (!_isFirstTime && _profile != null) _buildQrSection(),
                const SizedBox(height: 24),
                _buildFormSection(),
                const SizedBox(height: 32),
                _buildActionButtons(),
              ],
            ),
          ),
    );
  }

  Widget _buildQrSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
      ),
      child: Column(
        children: [
          QrImageView(
            data: "PANTAS_PROFILE:${_profile!.id}|${_profile!.fullName}|${_profile!.phone}",
            version: QrVersions.auto,
            size: 180.0,
          ),
          const SizedBox(height: 12),
          Text(_profile!.id, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E2A5E))),
          const Text('Scan this for Secure Handover', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildFormSection() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PROFILE INFORMATION',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E2A5E), fontSize: 14),
          ),
          const SizedBox(height: 16),
          
          // IMPORTANT NOTICE
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Note: Name, Email, and Phone cannot be changed once saved to maintain data integrity.',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          TextFormField(
            controller: _nameController,
            enabled: _isFirstTime,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            enabled: _isFirstTime,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email),
              border: OutlineInputBorder(),
            ),
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            enabled: _isFirstTime,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              prefixIcon: Icon(Icons.phone),
              border: OutlineInputBorder(),
            ),
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _deptController,
            decoration: const InputDecoration(
              labelText: 'Department / Company',
              prefixIcon: Icon(Icons.business),
              border: OutlineInputBorder(),
              helperText: 'This field is editable at any time.',
            ),
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        ElevatedButton(
          onPressed: _saveProfile,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E2A5E),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 55),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(_isFirstTime ? 'CREATE PROFILE NOW' : 'SAVE CHANGES'),
        ),
        if (!_isFirstTime) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _exportVCard,
            icon: const Icon(Icons.contact_phone),
            label: const Text('EXPORT CONTACT (VCARD)'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ],
    );
  }
}
