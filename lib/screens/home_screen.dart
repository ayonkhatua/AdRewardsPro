import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart'; 
import 'package:device_info_plus/device_info_plus.dart'; 
import 'package:dart_ipify/dart_ipify.dart'; 
import 'package:url_launcher/url_launcher.dart'; 
import 'package:unity_ads_plugin/unity_ads_plugin.dart'; 

import '../admin/admin_dashboard.dart'; 
import '../models/app_settings_model.dart';

import 'spin_screen.dart';
import 'scratch_screen.dart';
import 'refer_screen.dart';
import 'withdrawal_screen.dart';
import 'login_screen.dart'; 
import 'transaction_screen.dart';
import 'support_screen.dart'; 
import 'delete_account_screen.dart'; 
import 'privacy_policy_screen.dart'; // 👇 NAYA: Privacy Policy screen import kiya

const int CURRENT_APP_VERSION = 1;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0; 

  // System States
  bool _isLoading = true;
  bool _isMaintenance = false;
  bool _isBlocked = false;
  String _blockReason = "";
  
  // Admin Check
  bool _isAdminUser = false; 

  // Update States
  bool _isUpdateAvailable = false;
  String _updateUrl = "";
  String _updateMessage = "";

  // Ads States
  bool _adsEnabled = true;
  int _interAdInterval = 5; 
  int _tabTapCount = 0;

  List<Widget> get _tabs => [
    const HomeTab(),    
    const EarnTab(),    
    const ProfileTab(), 
  ];

  @override
  void initState() {
    super.initState();
    _runStartupChecks(); 
  }

  Future<void> _runStartupChecks() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return;

    try {
      final response = await supabase.from('app_settings').select().single();
      final settings = AppSettingsModel.fromJson(response);

      _adsEnabled = settings.adsEnabled;
      _interAdInterval = settings.interAdInterval;

      if (user.email == settings.adminEmail) {
        _isAdminUser = true;
        _adsEnabled = false; 
      }

      if (settings.isMaintenance && !_isAdminUser) {
        setState(() {
          _isMaintenance = true;
          _isLoading = false;
        });
        return; 
      }

      if (settings.appVersion > CURRENT_APP_VERSION) {
        setState(() {
          _isUpdateAvailable = true;
          _updateUrl = settings.updateUrl;
          _updateMessage = settings.updateMessage;
        });
        _showUpdateDialog();
      }

      final profileData = await supabase.from('profiles').select('is_blocked').eq('id', user.id).single();
      if (profileData['is_blocked'] == true) {
        _blockUser("Your account has been permanently blocked by the Administrator for violating app policies.");
        return; 
      }

      await _verifyDeviceAndIP(user.id);

    } catch (e) {
      debugPrint("Startup Check Error: $e");
    } finally {
      if (mounted && !_isMaintenance && !_isBlocked) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verifyDeviceAndIP(String currentUserId) async {
    try {
      final supabase = Supabase.instance.client;
      
      final deviceInfo = DeviceInfoPlugin();
      String deviceId = 'unknown_device';
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'unknown_ios';
      }

      String currentIp = 'unknown_ip';
      try {
        currentIp = await Ipify.ipv4();
      } catch (e) {
        debugPrint("IP fetch failed: $e");
      }

      final deviceCheck = await supabase.from('profiles')
          .select('id')
          .eq('device_id', deviceId)
          .neq('id', currentUserId);
          
      if (deviceCheck.isNotEmpty) {
        _blockUser("Multiple accounts detected on this device. Dual Apps are not allowed.");
        return;
      }

      if (currentIp != 'unknown_ip') {
        final ipCheck = await supabase.from('profiles')
            .select('id')
            .eq('last_ip', currentIp)
            .neq('id', currentUserId);
            
        if (ipCheck.isNotEmpty) {
          _blockUser("Multiple accounts detected on this Wi-Fi Network. Only 1 account per network is allowed.");
          return;
        }
      }

      await supabase.from('profiles').update({
        'device_id': deviceId,
        'last_ip': currentIp,
      }).eq('id', currentUserId);

    } catch (e) {
      debugPrint("Fraud Verification Error: $e");
    }
  }

  void _blockUser(String message) {
    if (mounted) {
      setState(() {
        _isBlocked = true;
        _blockReason = message;
        _isLoading = false;
      });
    }
  }

  void _showUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) => PopScope(
        canPop: false, 
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Update Required!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: Text(_updateMessage),
          actions: [
            ElevatedButton.icon(
              onPressed: () async {
                final url = Uri.parse(_updateUrl);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.download),
              label: const Text('Download Now'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6750A4), foregroundColor: Colors.white),
            )
          ],
        ),
      ),
    );
  }

  void _handleTabSwitch(int index) {
    setState(() {
      _currentIndex = index;
    });

    if (!_adsEnabled || _isAdminUser) return;

    _tabTapCount++;
    if (_tabTapCount >= _interAdInterval) {
      _tabTapCount = 0; 
      _showInterstitialAd();
    }
  }

  void _showInterstitialAd() {
    UnityAds.load(
      placementId: 'Interstitial_Android', 
      onComplete: (placementId) {
        UnityAds.showVideoAd(
          placementId: placementId,
          onFailed: (placementId, error, message) => debugPrint('Tab Ad Show Failed: $message'),
        );
      },
      onFailed: (placementId, error, message) => debugPrint('Tab Ad Load Failed: $message'),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF6A11CB)),
              SizedBox(height: 20),
              Text("Securing connection...", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    if (_isMaintenance) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.engineering_rounded, size: 80, color: Colors.orange),
                SizedBox(height: 20),
                Text("Under Maintenance", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                SizedBox(height: 10),
                Text("We are upgrading our servers. Please check back later.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      );
    }

    if (_isBlocked) {
      return Scaffold(
        backgroundColor: Colors.red.shade50,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.block_flipped, size: 80, color: Colors.red),
                const SizedBox(height: 20),
                const Text("Access Denied", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red)),
                const SizedBox(height: 10),
                Text(_blockReason, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8FD), 
      body: SafeArea(child: _tabs[_currentIndex]),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min, 
        children: [
          if (_adsEnabled && !_isAdminUser)
            Container(
              color: Colors.white,
              width: double.infinity,
              height: 50,
              child: UnityBannerAd(
                placementId: 'Banner_Android',
                onLoad: (placementId) => debugPrint('Banner Loaded'),
                onFailed: (placementId, error, message) => debugPrint('Banner Failed: $message'),
              ),
            ),
          NavigationBar(
            selectedIndex: _currentIndex,
            backgroundColor: Colors.white,
            elevation: 10,
            indicatorColor: const Color(0xFFEADDFF), 
            onDestinationSelected: _handleTabSwitch, 
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded, color: Color(0xFF6750A4)),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.card_giftcard_outlined),
                selectedIcon: Icon(Icons.card_giftcard_rounded, color: Color(0xFF6750A4)),
                label: 'Earn',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person_rounded, color: Color(0xFF6750A4)),
                label: 'Profile',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==========================================
// TAB 1: HOME TAB
// ==========================================
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late final Stream<Map<String, dynamic>> _userStream;
  bool _isAdmin = false; 

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      _userStream = Supabase.instance.client
          .from('profiles')
          .stream(primaryKey: ['id'])
          .eq('id', user.id)
          .map((data) => data.isNotEmpty ? data.first : {});
          
      _checkAdminStatus(user.email);
    } else {
      _userStream = Stream.value({}); 
    }
  }

  Future<void> _checkAdminStatus(String? userEmail) async {
    if (userEmail == null) return;
    try {
      final response = await Supabase.instance.client
          .from('app_settings')
          .select('admin_email')
          .single();
          
      if (mounted && response['admin_email'] == userEmail) {
        setState(() {
          _isAdmin = true;
        });
      }
    } catch (e) {
      debugPrint("Admin check error: $e");
    }
  }

  void _copyReferralCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Referral Code Copied!'), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _userStream,
      builder: (context, snapshot) {
        int walletBalance = 0;
        String referralCode = "LOADING...";

        if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
          walletBalance = snapshot.data!['wallet_balance'] ?? 0;
          referralCode = snapshot.data!['referral_code'] ?? "Generating...";
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          "Dashboard",
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1D1B20)),
                        ),
                        if (_isAdmin) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.admin_panel_settings, color: Colors.orange),
                            tooltip: 'Admin Panel',
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboard()));
                            },
                          ),
                        ],
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: const Color(0xFFEADDFF), width: 2),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.monetization_on, color: Color(0xFF6750A4), size: 20),
                          const SizedBox(width: 6),
                          Text(
                            "$walletBalance",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF6750A4)),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),

              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(color: const Color(0xFFE8DEF8), borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.account_balance_wallet, color: Color(0xFF1D192B), size: 28),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Available Balance", style: TextStyle(color: Color(0xFF79747E), fontSize: 14)),
                        Text("$walletBalance", style: const TextStyle(color: Color(0xFF6750A4), fontSize: 32, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ReferScreen()));
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 4))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Invite & Earn", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1D1B20))),
                      const SizedBox(height: 4),
                      const Text("Share your code to earn bonuses.", style: TextStyle(color: Color(0xFF79747E), fontSize: 14)),
                      const SizedBox(height: 16),
                      
                      Container(
                        padding: const EdgeInsets.only(left: 16, right: 8, top: 8, bottom: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDF8FD),
                          border: Border.all(color: const Color(0xFFEADDFF)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(referralCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.5)),
                            IconButton(
                              onPressed: () => _copyReferralCode(referralCode),
                              icon: const Icon(Icons.copy_rounded, color: Color(0xFF6750A4)),
                              splashRadius: 20,
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text("Bonus Tasks", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF79747E))),
              ),
              const SizedBox(height: 16),
              
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text("No tasks available right now.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ==========================================
// TAB 2: EARN TAB
// ==========================================
class EarnTab extends StatelessWidget {
  const EarnTab({super.key});

  Widget _buildListCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required Future<void> Function() onTap, 
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        onTap: () async {
          await onTap(); 
        }, 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Earn Coins", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1D1B20))),
          const SizedBox(height: 20),
          _buildListCard(
            context: context,
            title: 'Lucky Spin',
            subtitle: 'Spin the wheel & win daily rewards',
            icon: Icons.casino_rounded,
            iconBgColor: const Color(0xFFFFDBCB), 
            iconColor: const Color(0xFF311300),
            onTap: () async => await Navigator.push(context, MaterialPageRoute(builder: (_) => const SpinScreen())),
          ),
          _buildListCard(
            context: context,
            title: 'Scratch & Win',
            subtitle: 'Scratch cards for instant coins',
            icon: Icons.style_rounded,
            iconBgColor: const Color(0xFFC4EED0), 
            iconColor: const Color(0xFF00210C),
            onTap: () async => await Navigator.push(context, MaterialPageRoute(builder: (_) => const ScratchScreen())),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// TAB 3: PROFILE TAB
// ==========================================
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? 'No Email';

    return StreamBuilder<Map<String, dynamic>>(
      stream: Supabase.instance.client
          .from('profiles')
          .stream(primaryKey: ['id'])
          .eq('id', user?.id ?? '')
          .map((data) => data.isNotEmpty ? data.first : {}),
      builder: (context, snapshot) {
        
        int liveBalance = 0;
        if (snapshot.hasData && snapshot.data != null) {
          liveBalance = snapshot.data!['wallet_balance'] ?? 0;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Profile", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1D1B20))),
              const SizedBox(height: 20),
              
              Center(
                child: Column(
                  children: [
                    const CircleAvatar(radius: 40, backgroundColor: Color(0xFFEADDFF), child: Icon(Icons.person, size: 40, color: Color(0xFF6750A4))),
                    const SizedBox(height: 10),
                    Text(email, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8DEF8), 
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD0BCFF), width: 1),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Color(0xFF6750A4), size: 28),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Coin Value", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1D192B), fontSize: 16)),
                          SizedBox(height: 2),
                          Text("100 Coins = ₹2", style: TextStyle(color: Color(0xFF49454F), fontSize: 14, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF6750A4), size: 30),
                  title: const Text('Withdraw Funds', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Text('Balance: $liveBalance Coins', style: const TextStyle(color: Colors.grey, fontSize: 12)), 
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WithdrawalScreen())),
                ),
              ),
              
              const SizedBox(height: 20),
              
              const Text("Settings", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF79747E))),
              const SizedBox(height: 10),
              
              ListTile(
                leading: const Icon(Icons.receipt_long_rounded, color: Color(0xFF6750A4)),
                title: const Text('Transactions', style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const TransactionScreen()));
                },
              ),
              
              // 👇 NAYA: Privacy Policy Button
              ListTile(
                leading: const Icon(Icons.privacy_tip_rounded, color: Color(0xFF6A11CB)),
                title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()));
                },
              ),

              ListTile(
                leading: const Icon(Icons.support_agent_rounded, color: Color(0xFF6A11CB)),
                title: const Text('Help & Support', style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SupportScreen()));
                },
              ),

              ListTile(
                leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                title: const Text('Delete Account', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const DeleteAccountScreen()));
                },
              ),
              
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.red),
                title: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                onTap: () async {
                  await Supabase.instance.client.auth.signOut();
                  if(context.mounted) {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}