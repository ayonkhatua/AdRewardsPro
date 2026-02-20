import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

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
  late TextEditingController _interAdIntervalController; // 👇 NAYA: Tab count ke liye controller

  bool _adsEnabled = true;
  bool _isTestMode = true;

  @override
  void initState() {
    super.initState();
    _unityIdController = TextEditingController();
    _interAdIntervalController = TextEditingController(); // 👇 Initialize kiya
    _fetchAdSettings(); 
  }

  Future<void> _fetchAdSettings() async {
    try {
      final response = await _supabase.from('app_settings').select().single();
      final settings = AppSettingsModel.fromJson(response);
      
      if (mounted) {
        setState(() {
          _unityIdController.text = settings.unityGameId;
          _interAdIntervalController.text = settings.interAdInterval.toString(); // 👇 Model se value laaye
          _adsEnabled = settings.adsEnabled;
          _isTestMode = settings.isTestMode;
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

  Future<void> _updateSettings() async {
    setState(() => _isSaving = true);
    
    // Agar empty chhod diya ya galat daala toh default 5 lega taaki app crash na ho
    int adInterval = int.tryParse(_interAdIntervalController.text.trim()) ?? 5;

    try {
      await _supabase.from('app_settings').update({
        'unity_game_id': _unityIdController.text.trim(),
        'inter_ad_interval': adInterval, // 👇 Supabase mein save kiya
        'ads_enabled': _adsEnabled,
        'is_test_mode': _isTestMode,
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
    _interAdIntervalController.dispose(); // 👇 Dispose karna mat bhoolna
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

          // 👇 NAYA: Tab Switch Ad Interval ka Input Field
          TextField(
            controller: _interAdIntervalController,
            keyboardType: TextInputType.number, // Sirf numbers type karne dega
            decoration: InputDecoration(
              labelText: 'Tab Switch Ad Interval (e.g., 5)',
              helperText: 'Show an interstitial ad after this many tab switches',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.touch_app, color: Color(0xFF6A11CB)),
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
              title: const Text('Enable Test Mode', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Keep ON while testing to avoid account ban. Turn OFF for real ads.'),
              value: _isTestMode,
              activeColor: Colors.white,
              activeTrackColor: Colors.orange, 
              onChanged: (bool value) {
                setState(() {
                  _isTestMode = value;
                });
              },
            ),
          ),
          const SizedBox(height: 15),

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