import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';
// TODO: pubspec.yaml mein share_plus dalne ke baad ise uncomment karein

class ReferScreen extends StatefulWidget {
  const ReferScreen({super.key});

  @override
  State<ReferScreen> createState() => _ReferScreenState();
}

class _ReferScreenState extends State<ReferScreen> {
  String _referralCode = "LOADING...";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReferralCode();
  }

  // Database se Referral Code nikalna
  Future<void> _fetchReferralCode() async {
    final user = Supabase.instance.client.auth.currentUser;
    
    if (user == null) {
      setState(() {
        _referralCode = "AYON123"; 
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('referral_code')
          .eq('id', user.id)
          .single();

      setState(() {
        _referralCode = response['referral_code'] ?? "NO_CODE";
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching code: $e");
      setState(() => _isLoading = false);
    }
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: _referralCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 Referral Code Copied!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareCode() {
    // Professional Share Message
    final String shareMessage = "Hey! I'm earning real money on AdRewards Pro. 🚀\n\nDownload the app, use my Referral Code: *$_referralCode* and get a head start!\n\nLet's earn together!";
    
    // TODO: Jab pubspec.yaml mein package add ho jaye, tab is line ko uncomment kar dena
    // Share.share(shareMessage); 

    // Abhi testing ke liye SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share menu will open here in Live App!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF8FD), 
      appBar: AppBar(
        title: const Text('Refer & Earn', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  "Invite Friends & Earn",
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1D1B20)),
                ),
                
                const SizedBox(height: 20),

                // 3. STRICT CONDITION TEXT (Anti-Hacker Warning)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4CC), 
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFDE293), width: 2),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: const Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.security_rounded, color: Color(0xFF146C2E), size: 24),
                          SizedBox(width: 8),
                          Text("100% Verified Reward", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF146C2E))),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text(
                        "You will receive 100 Bonus Coins ONLY when your friend makes their FIRST SUCCESSFUL WITHDRAWAL.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF311300), fontSize: 14, fontWeight: FontWeight.w600, height: 1.5),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // 4. REFERRAL CODE BOX
                const Text("YOUR REFERRAL CODE", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
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