import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _referralController = TextEditingController();
  
  bool _isLoading = false;
  bool _isLoginMode = true;
  
  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  // ==========================================
  // EMAIL AUTH LOGIC (UNCHANGED)
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
        await supabase.auth.signInWithPassword(email: email, password: password);
        _navigateToHome();
      } else {
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
  // GOOGLE SIGN-IN LOGIC (FIXED)
  // ==========================================
  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);
    
    try {
      // 🔥 FIX 1: Pehle se existing session clear karo
      await GoogleSignIn().signOut();

      // 🔥 FIX 2: Web Client ID - Yeh Google Cloud Console se lo (Web Application type)
      // IMPORTANT: Yeh sirf WEB CLIENT ID honi chahiye, Android nahi!
      const webClientId = '567470905268-sh82ku8hkh0t50gl6pf4ob4p90d6kc0d.apps.googleusercontent.com';

      // 🔥 FIX 3: GoogleSignIn configure karo with scopes
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: webClientId,  // 👈 Yeh add karo
        serverClientId: webClientId,
        scopes: ['email', 'profile', 'openid'],  // 👈 Scopes add karo
      );

      // 🔥 FIX 4: Sign in with better error handling
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        setState(() => _isLoading = false);
        _showSnackBar('Sign in cancelled by user', Colors.orange);
        return; 
      }

      // 🔥 FIX 5: Authentication fetch karo with timeout
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;

      // Debug prints
      print('✅ Google Auth Success');
      print('ID Token exists: ${idToken != null}');
      print('Access Token exists: ${accessToken != null}');

      // 🔥 FIX 6: Strong null check
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Google ID Token is null or empty. Check your OAuth 2.0 Web Client ID configuration in Google Cloud Console.');
      }

      // 🔥 FIX 7: Supabase mein sign in with proper provider
      final AuthResponse response = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user != null) {
        print('✅ Supabase Auth Success: ${response.user!.email}');
        _navigateToHome();
      } else {
        throw Exception('Supabase returned null user');
      }

    } on PlatformException catch (e) {
      String errorMsg = 'Google Sign-In Error: ${e.message}';
      if (e.code == 'sign_in_failed') {
        errorMsg = 'Sign in failed. Check:\n1. SHA-1 fingerprint in Firebase/Google Cloud\n2. OAuth Consent Screen configured\n3. Web Client ID is correct';
      } else if (e.code == 'network_error') {
        errorMsg = 'Network error. Check your internet connection.';
      }
      _showSnackBar(errorMsg, Colors.red);
    } on AuthException catch (e) {
      _showSnackBar('Auth Error: ${e.message}', Colors.red);
    } catch (e) {
      _showSnackBar('Login Failed: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (context) => const HomeScreen())
      );
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message), 
          backgroundColor: color, 
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // ==========================================
  // UI BUILD (UNCHANGED)
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
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2), 
                    shape: BoxShape.circle
                  ),
                  child: const Icon(Icons.monetization_on_rounded, size: 60, color: Colors.white),
                ),
                const SizedBox(height: 20),
                Text(
                  _isLoginMode ? 'Welcome Back!' : 'Create Account',
                  style: GoogleFonts.poppins(
                    fontSize: 26, 
                    fontWeight: FontWeight.bold, 
                    color: Colors.white
                  ),
                ),
                const SizedBox(height: 30),

                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2), 
                        blurRadius: 20, 
                        offset: const Offset(0, 5)
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.email_outlined, color: Colors.purple.shade300),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12), 
                            borderSide: BorderSide.none
                          ),
                          filled: true, 
                          fillColor: Colors.grey.shade100,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline, color: Colors.purple.shade300),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12), 
                            borderSide: BorderSide.none
                          ),
                          filled: true, 
                          fillColor: Colors.grey.shade100,
                        ),
                      ),
                      if (!_isLoginMode) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _referralController,
                          decoration: InputDecoration(
                            labelText: 'Referral Code (Optional)',
                            prefixIcon: Icon(Icons.group_add_outlined, color: Colors.purple.shade300),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12), 
                              borderSide: BorderSide.none
                            ),
                            filled: true, 
                            fillColor: Colors.grey.shade100,
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24, 
                                  width: 24, 
                                  child: CircularProgressIndicator(color: Colors.white)
                                )
                              : Text(
                                  _isLoginMode ? 'LOGIN' : 'SIGN UP', 
                                  style: GoogleFonts.poppins(
                                    fontSize: 16, 
                                    fontWeight: FontWeight.bold, 
                                    color: Colors.white
                                  )
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => setState(() => _isLoginMode = !_isLoginMode),
                        child: Text(
                          _isLoginMode 
                            ? "Don't have an account? Sign Up" 
                            : "Already have an account? Login", 
                          style: const TextStyle(fontWeight: FontWeight.bold)
                        ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)
                      ),
                    ),
                    icon: const Icon(Icons.g_mobiledata, size: 40, color: Colors.red), 
                    label: Text(
                      'Sign in with Google', 
                      style: GoogleFonts.poppins(
                        fontSize: 16, 
                        fontWeight: FontWeight.w600
                      )
                    ),
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
