import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

// 👇 NAYA: Apna model import kiya
import '../../models/app_settings_model.dart';

class RewardsControlPage extends StatefulWidget {
  const RewardsControlPage({super.key});

  @override
  State<RewardsControlPage> createState() => _RewardsControlPageState();
}

class _RewardsControlPageState extends State<RewardsControlPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isSaving = false;

  late TextEditingController _minRewardController;
  late TextEditingController _maxRewardController;

  @override
  void initState() {
    super.initState();
    _minRewardController = TextEditingController();
    _maxRewardController = TextEditingController();
    _fetchRewards();
  }

  // ==========================================
  // 1. SUPABASE SE DATA LAANE KA LOGIC (MODEL KE SATH)
  // ==========================================
  Future<void> _fetchRewards() async {
    try {
      // Pura data ek sath laya
      final response = await _supabase.from('app_settings').select().single();
      
      // Model mein convert kiya
      final settings = AppSettingsModel.fromJson(response);
      
      if (mounted) {
        setState(() {
          // Ab safely model se variables nikal rahe hain
          _minRewardController.text = settings.minScratchReward.toString();
          _maxRewardController.text = settings.maxScratchReward.toString();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching rewards: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================
  // 2. SUPABASE MEIN DATA SAVE KARNE KA LOGIC
  // ==========================================
  Future<void> _updateRewards() async {
    setState(() => _isSaving = true);
    try {
      await _supabase.from('app_settings').update({
        'min_scratch_reward': int.parse(_minRewardController.text.trim()),
        'max_scratch_reward': int.parse(_maxRewardController.text.trim()),
      }).eq('id', 1);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Rewards Updated Successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Error updating rewards'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _minRewardController.dispose();
    _maxRewardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF6A11CB)));

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rewards Control', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Set the minimum and maximum coins users can win from Scratch Cards.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),

          TextField(
            controller: _minRewardController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Minimum Scratch Coins',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.remove_circle_outline, color: Colors.orange),
            ),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _maxRewardController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Maximum Scratch Coins',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.add_circle_outline, color: Colors.green),
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
              ),
              onPressed: _isSaving ? null : _updateRewards,
              child: _isSaving 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Save Rewards', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}