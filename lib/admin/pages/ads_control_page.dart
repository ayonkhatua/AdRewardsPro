import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

// 👇 NAYA: Apna model import kiya
import '../../models/app_settings_model.dart';

class AdsControlPage extends StatefulWidget {
  const AdsControlPage({super.key});

  @override
  State<AdsControlPage> createState() => _AdsControlPageState();
}

class _AdsControlPageState extends State<AdsControlPage> {
  final _supabase = Supabase.instance.client;
  
  bool _isLoading = true;
  bool _isSaving = false;

  late TextEditingController _unityIdController;
  bool _adsEnabled = true;

  @override
  void initState() {
    super.initState();
    _unityIdController = TextEditingController();
    _fetchAdSettings(); 
  }

  // ==========================================
  // 1. SUPABASE SE DATA LAANE KA LOGIC (MODEL KE SATH)
  // ==========================================
  Future<void> _fetchAdSettings() async {
    try {
      // Pura data ek sath laya
      final response = await _supabase.from('app_settings').select().single();
      
      // Model mein convert kiya
      final settings = AppSettingsModel.fromJson(response);
      
      if (mounted) {
        setState(() {
          // Ab bracket wale syntax ki jagah dot (.) use kar rahe hain
          _unityIdController.text = settings.unityGameId;
          _adsEnabled = settings.adsEnabled;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching ad settings: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load settings'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ==========================================
  // 2. SUPABASE MEIN DATA SAVE KARNE KA LOGIC
  // ==========================================
  Future<void> _updateSettings() async {
    setState(() => _isSaving = true);
    
    try {
      await _supabase.from('app_settings').update({
        'unity_game_id': _unityIdController.text.trim(),
        'ads_enabled': _adsEnabled,
      }).eq('id', 1); 

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Ads Settings Updated Successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Error updating ad settings: $e");
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
    _unityIdController.dispose();
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
          Text('Ads Monetization', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Control your Unity Ads directly from here. Changes will apply instantly to all users.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          
          TextField(
            controller: _unityIdController,
            decoration: InputDecoration(
              labelText: 'Android Game ID (Unity)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.numbers, color: Color(0xFF6A11CB)),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFF6A11CB), width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            child: SwitchListTile(
              title: const Text('Enable Ads in App', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Turn off to disable all video ads temporarily'),
              value: _adsEnabled,
              activeColor: Colors.white,
              activeTrackColor: const Color(0xFF6A11CB),
              onChanged: (bool value) {
                setState(() {
                  _adsEnabled = value;
                });
              },
            ),
          ),
          const SizedBox(height: 40),

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
                  : const Text('Save Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}