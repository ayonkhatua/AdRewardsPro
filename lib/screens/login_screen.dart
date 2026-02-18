import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // YE MISSING THA (Error fix)
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
  final _referralController = TextEditingController(); // Referral Code ke liye
  
  bool _isLoading = false;
  bool _isLoginMode = true; // Toggle between Login and Signup

  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _referralController.dispose();
    super.dispose();
  }

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

    if (!_isValidEmail(email)) {
      _showSnackBar('Please enter a valid email address.', Colors.orange);
      return;
    }

    if (password.length < 6) {
      _showSnackBar('Password must be at least 6 characters long.', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      if (_isLoginMode) {
        // --- LOGIN LOGIC ---
        try {
          await supabase.auth.signInWithPassword(email: email, password: password);
          _navigateToHome();
        } on AuthException catch (e) {
          // Specific Supabase Auth Errors
          if (e.message.contains('Invalid login credentials')) {
             _showSnackBar('Incorrect email or password. Please try again.', Colors.red);
          } else if (e.message.contains('Email not confirmed')) {
             _showSnackBar('Please verify your email address before logging in.', Colors.orange);
          } else {
             _showSnackBar(e.message, Colors.red); // Fallback to Supabase message
          }
        } catch (e) {
           _showSnackBar('Login failed. Please check your connection.', Colors.red);
        }
      } else {
        // --- SIGNUP LOGIC ---
        try {
          final AuthResponse res = await supabase.auth.signUp(email: email, password: password);
          
          // Agar signup successful hua aur user ne referral code daala hai
          if (res.user != null && referralCode.isNotEmpty) {
             await _processReferralCode(res.user!.id, referralCode);
          }
          
          _showSnackBar('Account created successfully! You can now login.', Colors.green);
          
          // Signup ke baad wapas Login mode mein bhej do
          setState(() {
            _isLoginMode = true;
            _referralController.clear();
            _passwordController.clear();
          });

        } on AuthException catch (e) {
           // Specific Signup Errors
           if (e.message.contains('User already registered')) {
             _showSnackBar('This email is already registered. Please login.', Colors.orange);
             setState(() => _isLoginMode = true); // Switch to login
           } else {
             _showSnackBar(e.message, Colors.red);
           }
        } catch (e) {
           _showSnackBar('Signup failed. Please try again later.', Colors.red);
        }
      }
    } catch (e) {
      // Global error catcher
      _showSnackBar('An unexpected error occurred: ${e.toString()}', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(email);
  }

  // Database me referral link banane ka function
  Future<void> _processReferralCode(String newUserId, String enteredCode) async {
    try {
      // 1. Check karo ki code kiska hai
      final response = await supabase
          .from('profiles')
          .select('id')
          .eq('referral_code', enteredCode)
          .maybeSingle(); // Use maybeSingle to avoid exception if not found

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
      // Ensure this is the correct Web Client ID from Google Cloud Console
      const webClientId = '1012104223725-bhln7pal8vhscomur2os38gqmhjhpk9t.apps.googleusercontent.com';

      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: null, // Android/iOS client ID should be null for new Flutter integration
        serverClientId: webClientId,
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // User canceled the sign-in
        if (mounted) setState(() => _isLoading = false);
        return; 
      }

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        throw 'Google Authentication failed. Tokens are missing.';
      }

      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      _navigateToHome();
    } on PlatformException catch (e) {
      // Specific Google Sign-In errors (like Error 10)
      if (e.code == 'sign_in_failed') {
         _showSnackBar('Google Sign-In failed. Please check your internet or try again later.', Colors.red);
         print("Google Sign In Error Details: ${e.message}, Code: ${e.code}, Details: ${e.details}");
      } else {
        _showSnackBar('Google Sign-In Error: ${e.message}', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Google Login Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        SnackBar(
          content: Text(message), 
          backgroundColor: color, 
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16), // Add margin for better look
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  // ==========================================
  // UI SECTION (UI remains largely the same, just refined)
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
                      // Email Field
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.email_outlined, color: Colors.purple.shade300),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Password Field
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline, color: Colors.purple.shade300),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                        ),
                      ),
                      
                      // Referral Code Field (Signup Only)
                      if (!_isLoginMode) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _referralController,
                          decoration: InputDecoration(
                            labelText: 'Referral Code (Optional)',
                            prefixIcon: Icon(Icons.group_add_outlined, color: Colors.purple.shade300),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          ),
                        ),
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
                              ? const SizedBox(
                                  width: 24, 
                                  height: 24, 
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
                                )
                              : Text(
                                  _isLoginMode ? 'LOGIN' : 'SIGN UP', 
                                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)
                                ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // TOGGLE MODE
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
                                _isLoginMode = !_isLoginMode; 
                                // Optional: Clear fields when switching
                                // _emailController.clear();
                                // _passwordController.clear();
                                _referralController.clear();
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
                    // Using a network image for the icon. Ensure you have internet access.
                    // Ideally, use a local asset: Image.asset('assets/google_logo.png', height: 24)
                    icon: Image.network(
                      'https://cdn-icons-png.flaticon.com/512/300/300221.png', // Stable Google Icon link
                      height: 24,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.public, color: Colors.blue),
                    ),
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