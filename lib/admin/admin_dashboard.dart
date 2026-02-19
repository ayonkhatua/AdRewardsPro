import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

// 👇 NAYA: Apna banaya hua model yahan import kiya
import '../models/app_settings_model.dart';

// Aapke saare admin pages
import 'pages/overview_page.dart';
import 'pages/ads_control_page.dart';
import 'pages/rewards_control_page.dart';
import 'pages/manage_users_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  bool _isSecure = false;

  final _supabase = Supabase.instance.client;

  final List<String> _titles = [
    'Dashboard Overview',
    'Ads Settings',
    'Rewards Control',
    'Manage Users'
  ];

  final List<Widget> _pages = const [
    OverviewPage(),
    AdsControlPage(),
    RewardsControlPage(),
    ManageUsersPage(),
  ];

  @override
  void initState() {
    super.initState();
    _verifyAdminSecurity();
  }

  // ==========================================
  // 🛡️ SECURITY CHECK LOGIC (UPDATED WITH MODEL)
  // ==========================================
  Future<void> _verifyAdminSecurity() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) throw Exception('Koi login nahi hai');

      // 1. Supabase se saara data laya
      final response = await _supabase.from('app_settings').select().single();
      
      // 2. Data ko Model mein convert kiya (Magic happens here! ✨)
      final settings = AppSettingsModel.fromJson(response);
      
      // 3. Ab safely email check kar rahe hain
      if (settings.adminEmail == currentUser.email) {
        if (mounted) {
          setState(() {
            _isSecure = true;
            _isLoading = false;
          });
        }
      } else {
        _kickOut();
      }
    } catch (e) {
      debugPrint("Security Blocked: $e");
      _kickOut();
    }
  }

  void _kickOut() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Access Denied! You are not an Admin.'), backgroundColor: Colors.red),
      );
      Navigator.pop(context); 
    }
  }

  void _onMenuTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.pop(context); 
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Color(0xFF6A11CB))),
      );
    }

    if (!_isSecure) return const Scaffold();

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex], style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6A11CB),
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF6A11CB)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.security, color: Colors.orangeAccent, size: 40),
                  const SizedBox(height: 10),
                  Text('Admin Panel', style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  Text('${_supabase.auth.currentUser?.email}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            _buildDrawerItem(icon: Icons.dashboard, title: 'Overview', index: 0),
            _buildDrawerItem(icon: Icons.ad_units, title: 'Ads Settings', index: 1),
            _buildDrawerItem(icon: Icons.card_giftcard, title: 'Rewards Control', index: 2),
            _buildDrawerItem(icon: Icons.people, title: 'Manage Users', index: 3),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.red),
              title: const Text('Exit Admin Panel', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () => Navigator.pop(context), 
            ),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
    );
  }

  Widget _buildDrawerItem({required IconData icon, required String title, required int index}) {
    final isSelected = _selectedIndex == index;
    return ListTile(
      leading: Icon(icon, color: isSelected ? const Color(0xFF6A11CB) : Colors.grey),
      title: Text(
        title, 
        style: TextStyle(
          color: isSelected ? const Color(0xFF6A11CB) : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
        )
      ),
      selected: isSelected,
      selectedTileColor: const Color(0xFFEADDFF).withOpacity(0.5), 
      onTap: () => _onMenuTap(index),
    );
  }
}