import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Copy feature ke liye
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:share_plus/share_plus.dart'; // Asli share feature ke liye baad mein use karenge

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
    
    // Testing mode bypass (Agar user login nahi hai)
    if (user == null) {
      setState(() {
        _referralCode = "AYON123"; // Dummy code
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
    // TODO: Jab app playstore/website par jayega tab Share.share() lagayenge
    final String shareMessage = "Hey! Download this amazing earning app. Use my referral code $_referralCode and earn daily coins!";
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share menu will open here!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    // Share.share(shareMessage); // Asli code aisa hoga
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF8FD), // Pastel background
      appBar: AppBar(
        title: const Text('Refer & Earn'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
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
                    color: const Color(0xFFEADDFF), // Pastel Purple
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF6750A4).withOpacity(0.2), blurRadius: 30, spreadRadius: 5)
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
                
                const SizedBox(height: 15),

                // 3. STRICT CONDITION TEXT (Jo aapne bola tha)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4CC), // Pastel Yellow Warning
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFDE293), width: 2),
                  ),
                  child: const Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info_outline_rounded, color: Color(0xFF311300), size: 20),
                          SizedBox(width: 8),
                          Text("How it works?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF311300))),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        "When your friend downloads the app using your code and makes their FIRST WITHDRAWAL, you will get 100 Bonus Coins instantly!",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF311300), fontSize: 14, fontWeight: FontWeight.w500, height: 1.4),
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