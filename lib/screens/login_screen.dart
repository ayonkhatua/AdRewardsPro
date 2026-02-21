import 'dart:async';
import 'dart:io'; // 👇 NAYA: Device info ke liye
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:device_info_plus/device_info_plus.dart'; // 👇 NAYA: Device ID nikalne ke liye
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _referralController = TextEditingController();
  
  bool _isLoading = false;
  bool _isLoginMode = true;
  
  final supabase = Supabase.instance.client;
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    
    // 👇 UPDATED: Listener ab direct Home par nahi bhejega, pehle Device ID check karega
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) async {
      if (data.event == AuthChangeEvent.signedIn) {
        final user = data.session?.user;
        if (user != null) {
          await _processStrictLoginCheck(user.id);
        }
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _referralController.dispose();
    _authSubscription.cancel(); 
    super.dispose();
  }

  // ==========================================
  // 🛡️ STRICT DEVICE ID VERIFICATION LOGIC
  // ==========================================
  Future<void> _processStrictLoginCheck(String currentUserId) async {
    setState(() => _isLoading = true);
    
    try {
      // 1. Phone ka actual Device ID nikalo
      final deviceInfo = DeviceInfoPlugin();
      String currentDeviceId = 'unknown_device';
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        currentDeviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        currentDeviceId = iosInfo.identifierForVendor ?? 'unknown_ios';
      }

      // 2. Database mein check karo kya is Device ID par koi AUR account hai?
      final existingAccounts = await supabase
          .from('profiles')
          .select('id')
          .eq('device_id', currentDeviceId)
          .neq('id', currentUserId);

      // 3. Agar koi purana account mil gaya -> Strict Block!
      if (existingAccounts.isNotEmpty) {
        await supabase.auth.signOut(); // Naye account ko turant bahar phenko
        if (mounted) {
          _showDeviceRestrictedDialog();
        }
      } else {
        // 4. Clean Device! Is naye user ke sath ye Device ID link kar do
        await supabase
            .from('profiles')
            .update({'device_id': currentDeviceId})
            .eq('id', currentUserId);
            
        _navigateToHome();
      }
    } catch (e) {
      _showSnackBar("Security check failed: $e", Colors.red);
      await supabase.auth.signOut();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showDeviceRestrictedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Device Restricted', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'This device is already linked to another AdRewards Pro account.\n\nTo create or use a new account, you must first log in to your ORIGINAL account and select "Delete Account" from the Profile Settings.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A11CB), foregroundColor: Colors.white),
            child: const Text('UNDERSTOOD', style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  // ==========================================
  // EMAIL AUTH LOGIC
  // ==========================================
  Future<void> _handleAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final referralCode = _referralController.text.trim();

    if (email.isEmpty || password.length < 6) {
      _showSnackBar('Invalid email or password', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      if (_isLoginMode) {
        await supabase.auth.signInWithPassword(email: email, password: password);
      } else {
        final AuthResponse res = await supabase.auth.signUp(email: email, password: password);
        
        if (res.user != null) {
          if (referralCode.isNotEmpty) {
             await _processReferralCode(res.user!.id, referralCode);
          }
          _showSnackBar('Account created! Logging in...', Colors.green);
          // Note: AuthListener automatically handle karega aage ka process
        }
      }
    } on AuthException catch (e) {
      _showSnackBar(e.message, Colors.red);
      setState(() => _isLoading = false);
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
      setState(() => _isLoading = false);
    } 
  }

  Future<void> _processReferralCode(String newUserId, String enteredCode) async {
    try {
      final response = await supabase.from('profiles').select('id').eq('referral_code', enteredCode).maybeSingle(); 
      if (response != null && response['id'] != null) {
        await supabase.from('profiles').update({'referred_by': response['id']}).eq('id', newUserId);
      }
    } catch (_) {}
  }

  // ==========================================
  // GOOGLE SIGN-IN LOGIC (WEB OAUTH)
  // ==========================================
  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'com.hypernest.adrewardspro://login-callback',
      );
    } on AuthException catch (e) {
      _showSnackBar(e.message, Colors.red);
      setState(() => _isLoading = false);
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
      setState(() => _isLoading = false);
    } 
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating),
      );
    }
  }

  // ==========================================
  // UI BUILD
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.monetization_on_rounded, size: 60, color: Colors.white),
                ),
                const SizedBox(height: 20),
                Text(
                  _isLoginMode ? 'Welcome Back!' : 'Create Account',
                  style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 30),

                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 5))],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.email_outlined, color: Colors.purple.shade300),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          filled: true, fillColor: Colors.grey.shade100,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline, color: Colors.purple.shade300),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          filled: true, fillColor: Colors.grey.shade100,
                        ),
                      ),
                      if (!_isLoginMode) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _referralController,
                          decoration: InputDecoration(
                            labelText: 'Referral Code (Optional)',
                            prefixIcon: Icon(Icons.group_add_outlined, color: Colors.purple.shade300),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            filled: true, fillColor: Colors.grey.shade100,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleAuth,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6A11CB),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading
                              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white))
                              : Text(_isLoginMode ? 'LOGIN' : 'SIGN UP', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => setState(() => _isLoginMode = !_isLoginMode),
                        child: Text(_isLoginMode ? "Don't have an account? Sign Up" : "Already have an account? Login", style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _googleSignIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white, 
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.g_mobiledata, size: 40, color: Colors.red), 
                    label: Text('Sign in with Google', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}