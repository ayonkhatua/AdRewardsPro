import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 👇 Apna Model aur Dashboard import kiya
import '../models/app_settings_model.dart';
import 'admin_dashboard.dart';

class AdminLoginChecker extends StatefulWidget {
  const AdminLoginChecker({super.key});

  @override
  State<AdminLoginChecker> createState() => _AdminLoginCheckerState();
}

class _AdminLoginCheckerState extends State<AdminLoginChecker> {
  
  @override
  void initState() {
    super.initState();
    _checkAdminAccess(); // Screen khulte hi check shuru
  }

  Future<void> _checkAdminAccess() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        _kickOut('Please login first.');
        return;
      }

      // 1. Supabase se settings laya
      final response = await supabase.from('app_settings').select().single();
      
      // 2. Model mein convert kiya
      final settings = AppSettingsModel.fromJson(response);

      // 3. Email Check (Security)
      if (user.email == settings.adminEmail) {
        if (mounted) {
          // ✅ Admin hai -> Dashboard par bhej do (pushReplacement taaki back dabane par wapas checker par na aaye)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AdminDashboard()),
          );
        }
      } else {
        // ❌ Admin nahi hai -> Bahar nikal do
        _kickOut('Access Denied! You are not the Admin.');
      }
    } catch (e) {
      debugPrint("Admin Check Error: $e");
      _kickOut('Error verifying security. Try again.');
    }
  }

  void _kickOut(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
      Navigator.pop(context); // Wapas User Profile / Home page par bhej dega
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ye screen sirf 1-2 second ke liye dikhegi jab checking chal rahi hogi
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF6A11CB)),
            SizedBox(height: 20),
            Text(
              'Verifying Admin Security...',
              style: TextStyle(
                fontSize: 16, 
                fontWeight: FontWeight.bold, 
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}