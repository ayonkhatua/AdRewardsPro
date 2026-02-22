import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/app_settings_model.dart';

class SystemControlPage extends StatefulWidget {
  const SystemControlPage({super.key});

  @override
  State<SystemControlPage> createState() => _SystemControlPageState();
}

class _SystemControlPageState extends State<SystemControlPage> {
  final _supabase = Supabase.instance.client;
  
  bool _isLoading = true;
  bool _isSaving = false;

  bool _isMaintenance = false;
  late TextEditingController _appVersionController;
  late TextEditingController _updateUrlController;
  late TextEditingController _updateMessageController;

  @override
  void initState() {
    super.initState();
    _appVersionController = TextEditingController();
    _updateUrlController = TextEditingController();
    _updateMessageController = TextEditingController();
    _fetchSystemSettings(); 
  }

  Future<void> _fetchSystemSettings() async {
    try {
      final response = await _supabase.from('app_settings').select().single();
      final settings = AppSettingsModel.fromJson(response);
      
      if (mounted) {
        setState(() {
          _isMaintenance = settings.isMaintenance;
          _appVersionController.text = settings.appVersion.toString();
          _updateUrlController.text = settings.updateUrl;
          _updateMessageController.text = settings.updateMessage;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching system settings: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load settings'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 🔥 NAYA FUNCTION: Sirf Maintenance Mode ko LIVE update karne ke liye
  Future<void> _updateMaintenanceLive(bool value) async {
    // UI ko turant update karo taaki switch ghoom jaye
    setState(() {
      _isMaintenance = value;
    });

    try {
      // Database mein direct update bhejo
      await _supabase.from('app_settings').update({
        'is_maintenance': value,
      }).eq('id', 1);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Maintenance Mode ${value ? "ON" : "OFF"} ho gaya!'),
            backgroundColor: value ? Colors.red : Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error updating maintenance mode: $e");
      // Agar error aaye toh switch ko wapas purani state mein daal do
      setState(() {
        _isMaintenance = !value;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Failed to update Maintenance Mode'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateSettings() async {
    setState(() => _isSaving = true);
    
    try {
      await _supabase.from('app_settings').update({
        'is_maintenance': _isMaintenance,
        'app_version': int.parse(_appVersionController.text.trim()),
        'update_url': _updateUrlController.text.trim(),
        'update_message': _updateMessageController.text.trim(),
      }).eq('id', 1); 

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ System Settings Updated!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Error updating system settings: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Failed to update settings'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _appVersionController.dispose();
    _updateUrlController.dispose();
    _updateMessageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF6A11CB)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('System Control', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Manage app updates and maintenance mode.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),

          // MAINTENANCE MODE SWITCH
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red.shade300),
              borderRadius: BorderRadius.circular(12),
              color: Colors.red.shade50,
            ),
            child: SwitchListTile(
              title: const Text('Maintenance Mode', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              subtitle: const Text('Turn ON to block users from accessing the app during updates.'),
              value: _isMaintenance,
              activeThumbColor: Colors.white,
              activeTrackColor: Colors.red,
              onChanged: (bool value) {
                // Yahan naya live function call kiya hai
                _updateMaintenanceLive(value);
              },
            ),
          ),
          const SizedBox(height: 30),

          Text('App Update Settings', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),

          // APP VERSION
          TextField(
            controller: _appVersionController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Latest App Version Code (e.g., 2)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.info_outline, color: Color(0xFF6A11CB)),
            ),
          ),
          const SizedBox(height: 20),

          // UPDATE URL
          TextField(
            controller: _updateUrlController,
            decoration: InputDecoration(
              labelText: 'App Download Link (Play Store / Drive Link)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.link, color: Color(0xFF6A11CB)),
            ),
          ),
          const SizedBox(height: 20),

          // UPDATE MESSAGE
          TextField(
            controller: _updateMessageController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Update Message for Users',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.message, color: Color(0xFF6A11CB)),
            ),
          ),
          const SizedBox(height: 40),

          // SAVE BUTTON
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A11CB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 5,
              ),
              onPressed: _isSaving ? null : _updateSettings,
              child: _isSaving 
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save System Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}