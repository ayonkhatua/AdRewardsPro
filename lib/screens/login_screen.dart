import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart'; 
import 'home_screen.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _referralController = TextEditingController(); // NAYA: Referral Code ke liye
  
  bool _isLoading = false;
  bool _isLoginMode = true; // Toggle between Login and Signup

  final supabase = Supabase.instance.client;

  // ==========================================
  // LOGIC SECTION
  // ==========================================

  Future<void> _handleAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final referralCode = _referralController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Please fill all required fields.', Colors.red);
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      if (_isLoginMode) {
        // --- LOGIN LOGIC ---
        await supabase.auth.signInWithPassword(email: email, password: password);
        _navigateToHome();
      } else {
        // --- SIGNUP LOGIC ---
        final AuthResponse res = await supabase.auth.signUp(email: email, password: password);
        
        // Agar signup successful hua aur user ne referral code daala hai
        if (res.user != null && referralCode.isNotEmpty) {
           await _processReferralCode(res.user!.id, referralCode);
        }
        
        _showSnackBar('Account created! You can now login.', Colors.green);
        
        // Signup ke baad wapas Login mode mein bhej do
        setState(() {
          _isLoginMode = true;
          _referralController.clear();
          _passwordController.clear();
        });
      }
    } catch (e) {
      _showSnackBar(e.toString(), Colors.red);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // Database me referral link banane ka function
  Future<void> _processReferralCode(String newUserId, String enteredCode) async {
    try {
      // 1. Check karo ki code kiska hai
      final response = await supabase
          .from('profiles')
          .select('id')
          .eq('referral_code', enteredCode)
          .maybeSingle();

      // 2. Agar code mil gaya (matlab sahi hai), toh naye user ke profile me 'referred_by' add kar do
      if (response != null && response['id'] != null) {
        final referrerId = response['id'];
        
        await supabase.from('profiles').update({
          'referred_by': referrerId
        }).eq('id', newUserId);
      }
    } catch (e) {
      print("Referral Code Error: $e");
      // Hum app crash nahi karenge agar referral code galat ho
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);
    try {
      const webClientId = '1012104223725-h8fgitcn88suslhbc791lcsvjvoo6m15.apps.googleusercontent.com';

      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: webClientId,
        serverClientId: webClientId,
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return; 
      }

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) throw 'Google Tokens missing';

      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      _navigateToHome();
    } catch (e) {
      _showSnackBar('Google Login Error: $e', Colors.red);
    }
    if (mounted) setState(() => _isLoading = false);
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
  // UI SECTION
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
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. LOGO / ICON
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.monetization_on_rounded, size: 60, color: Colors.white),
                ),
                const SizedBox(height: 20),
                Text(
                  _isLoginMode ? 'Welcome Back!' : 'Create Account',
                  style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  _isLoginMode ? 'Login to start earning rewards' : 'Join us and start earning today!',
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 40),

                // 2. INPUT CARD
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: Column(
                    children: [
                      _buildTextField(_emailController, 'Email Address', Icons.email_outlined, false),
                      const SizedBox(height: 16),
                      _buildTextField(_passwordController, 'Password', Icons.lock_outline, true),
                      
                      // NAYA: Referral Code sirf Signup me dikhega
                      if (!_isLoginMode) ...[
                        const SizedBox(height: 16),
                        _buildTextField(_referralController, 'Referral Code (Optional)', Icons.group_add_outlined, false),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      // MAIN BUTTON
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleAuth,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6A11CB),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(
                                  _isLoginMode ? 'LOGIN' : 'SIGN UP', 
                                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)
                                ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // TOGGLE LINK
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isLoginMode ? "Don't have an account? " : "Already have an account? ", 
                            style: GoogleFonts.poppins(color: Colors.grey)
                          ),
                          GestureDetector(
                            onTap: _isLoading ? null : () {
                              setState(() {
                                _isLoginMode = !_isLoginMode; // Mode change
                                _referralController.clear(); // Clear referral code
                              });
                            },
                            child: Text(
                              _isLoginMode ? "Sign Up" : "Login", 
                              style: GoogleFonts.poppins(color: const Color(0xFF6A11CB), fontWeight: FontWeight.bold)
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                Row(
                  children: [
                    const Expanded(child: Divider(color: Colors.white38)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text("OR CONTINUE WITH", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                    ),
                    const Expanded(child: Divider(color: Colors.white38)),
                  ],
                ),
                const SizedBox(height: 30),

                // 3. GOOGLE BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _googleSignIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    icon: Image.network('https://img.icons8.com/color/48/000000/google-logo.png', height: 24),
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

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, bool isPass) {
    return TextField(
      controller: controller,
      obscureText: isPass,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.purple.shade300),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        filled: true,
        fillColor: Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
    );
  }
}