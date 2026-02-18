import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // PlatformException ke liye zaroori
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart'; // Ensure ye file exist karti hai

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _referralController = TextEditingController();
  
  bool _isLoading = false;
  bool _isLoginMode = true; // Toggle Login/Signup
  
  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  // ==========================================
  // 2. EMAIL AUTH LOGIC
  // ==========================================
  Future<void> _handleAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final referralCode = _referralController.text.trim();

    if (email.isEmpty || password.length < 6) {
      _showSnackBar('Please enter a valid email and password (min 6 chars)', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      if (_isLoginMode) {
        // --- LOGIN ---
        await supabase.auth.signInWithPassword(email: email, password: password);
        _navigateToHome();
      } else {
        // --- SIGNUP ---
        final AuthResponse res = await supabase.auth.signUp(email: email, password: password);
        
        if (res.user != null) {
          if (referralCode.isNotEmpty) {
             await _processReferralCode(res.user!.id, referralCode);
          }
          
          _showSnackBar('Account created! Please Login.', Colors.green);
          setState(() {
            _isLoginMode = true;
            _referralController.clear();
            _passwordController.clear();
          });
        } else {
           _showSnackBar('Signup failed. Please try again.', Colors.red);
        }
      }
    } on AuthException catch (e) {
      _showSnackBar(e.message, Colors.red);
    } catch (e) {
      _showSnackBar('An unexpected error occurred.', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _processReferralCode(String newUserId, String enteredCode) async {
    try {
      final response = await supabase
          .from('profiles')
          .select('id')
          .eq('referral_code', enteredCode)
          .maybeSingle(); 

      if (response != null && response['id'] != null) {
        await supabase.from('profiles').update({
          'referred_by': response['id']
        }).eq('id', newUserId);
      } else {
        print("Invalid Referral Code.");
      }
    } catch (e) {
      print("Referral Logic Error: $e");
    }
  }

  // ==========================================
  // 3. GOOGLE SIGN-IN LOGIC (DIAGNOSTIC)
  // ==========================================
  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);
    try {
      // Is Web Client ID ko replace mat karna
      const webClientId = '567470905268-sh82ku8hkh0t50gl6pf4ob4p90d6kc0d.apps.googleusercontent.com';

      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: null, 
        serverClientId: webClientId,
      );

      final googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; 
      }

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw 'ID Token Missing';
      }

      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      _navigateToHome();

    } on PlatformException catch (e) {
      _showSnackBar('Google Sign-In Error: ${e.message}', Colors.red);
    } on AuthException catch (e) {
      _showSnackBar(e.message, Colors.red);
    } catch (e) {
      _showSnackBar('Login Failed: $e', Colors.red);
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
        SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating),
      );
    }
  }

  // ==========================================
  // 4. UI BUILD (WITH DEBUG CONSOLE)
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
                  // Logo
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

                  // Input Card
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
                  // Google Button
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