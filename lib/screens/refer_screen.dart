import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart'; 

class ReferScreen extends StatefulWidget {
  const ReferScreen({super.key});

  @override
  State<ReferScreen> createState() => _ReferScreenState();
}

class _ReferScreenState extends State<ReferScreen> {
  String _referralCode = "LOADING...";
  int _referralBonus = 100; // Default referrer bonus
  int _joiningBonus = 50;   // 👇 NAYA: Default joining bonus for friend
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData(); 
  }

  // Database se Referral Code aur Admin Bonus Limits nikalna
  Future<void> _fetchData() async {
    final user = Supabase.instance.client.auth.currentUser;

    try {
      // 1. Admin Panel se DONO dynamic bonus fetch karo
      final settingsResponse = await Supabase.instance.client
          .from('app_settings')
          .select('referral_bonus_amount, joining_bonus_amount') // 👇 NAYA: Joining bonus bhi fetch kiya
          .single();
          
      int fetchedReferBonus = settingsResponse['referral_bonus_amount'] ?? 100;
      int fetchedJoinBonus = settingsResponse['joining_bonus_amount'] ?? 50;

      if (user == null) {
        if (mounted) {
          setState(() {
            _referralCode = "AYON123"; 
            _referralBonus = fetchedReferBonus;
            _joiningBonus = fetchedJoinBonus;
            _isLoading = false;
          });
        }
        return;
      }

      // 2. User ka referral code fetch karo
      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select('referral_code')
          .eq('id', user.id)
          .single();

      if (mounted) {
        setState(() {
          _referralCode = profileResponse['referral_code'] ?? "NO_CODE";
          _referralBonus = fetchedReferBonus;
          _joiningBonus = fetchedJoinBonus;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: _referralCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 Invite Code Copied!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareCode() {
    // 👇 NAYA: AdRewards Pro ke liye Earning Share Message (with Joining Bonus info)
    final String shareMessage = "Hey! I'm earning real money on AdRewards Pro. 🚀\n\nDownload the app, use my Invite Code: *$_referralCode* and get an instant $_joiningBonus Coins Welcome Bonus!\n\nLet's earn together!";
    
    Share.share(shareMessage); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF8FD), 
      appBar: AppBar(
        title: const Text('Refer & Earn', style: TextStyle(fontWeight: FontWeight.bold)), // 👇 TEXT UPDATE
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1D1B20)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF6750A4)))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. ILLUSTRATION / ICON
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEADDFF), 
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF6750A4).withOpacity(0.15), blurRadius: 30, spreadRadius: 5)
                    ]
                  ),
                  child: const Icon(Icons.groups_rounded, size: 80, color: Color(0xFF6750A4)),
                ),
                
                const SizedBox(height: 30),

                // 2. MAIN HEADING
                const Text(
                  "Invite Friends & Earn", // 👇 TEXT UPDATE
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1D1B20)),
                ),
                
                const SizedBox(height: 20),

                // 3. STRICT CONDITION TEXT (Earning Theme)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4CC), 
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFDE293), width: 2),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.verified_rounded, color: Color(0xFF146C2E), size: 24), // 👇 ICON UPDATE
                          SizedBox(width: 8),
                          Text("Verified Reward", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF146C2E))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // 👇 NAYA: Both bonuses mentioned clearly
                      Text(
                        "You will receive $_referralBonus Coins when your friend joins AdRewards Pro using your code. Your friend will also get $_joiningBonus Coins instantly!",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF311300), fontSize: 14, fontWeight: FontWeight.w600, height: 1.5),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // 4. REFERRAL CODE BOX
                const Text("YOUR INVITE CODE", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 10),
                
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF6750A4).withOpacity(0.3), width: 2),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
                    ]
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _referralCode,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 3, color: Color(0xFF6750A4)),
                      ),
                      IconButton(
                        onPressed: _copyCode,
                        icon: const Icon(Icons.copy_rounded, color: Color(0xFF6750A4), size: 28),
                        tooltip: "Copy Code",
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // 5. SHARE BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: _shareCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6750A4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      elevation: 5,
                    ),
                    icon: const Icon(Icons.share_rounded, color: Colors.white),
                    label: const Text(
                      "SHARE NOW",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}