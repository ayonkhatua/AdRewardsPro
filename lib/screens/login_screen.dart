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
  
  // NAYA: Logs store karne ke liye list
  List<String> _logs = [];

  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  // ==========================================
  // 1. ON-SCREEN LOGGER FUNCTION
  // ==========================================
  void _addLog(String message) {
    // Current time ke sath message add karega
    String timestamp = "${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second}";
    setState(() {
      _logs.insert(0, "[$timestamp] $message"); // Newest log upar aayega
    });
    print("DEBUG: $message"); // Console me bhi print karega
  }

  // ==========================================
  // 2. EMAIL AUTH LOGIC
  // ==========================================
  Future<void> _handleAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final referralCode = _referralController.text.trim();

    _addLog("Starting Email Auth...");

    if (email.isEmpty || password.length < 6) {
      _addLog("❌ Validation Error: Email empty or Password < 6 chars");
      _showSnackBar('Check inputs', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      if (_isLoginMode) {
        // --- LOGIN ---
        _addLog("Attempting SignIn for: $email");
        await supabase.auth.signInWithPassword(email: email, password: password);
        _addLog("✅ Login Successful!");
        _navigateToHome();
      } else {
        // --- SIGNUP ---
        _addLog("Attempting SignUp for: $email");
        final AuthResponse res = await supabase.auth.signUp(email: email, password: password);
        
        _addLog("✅ SignUp Auth Response Received.");
        
        if (res.user != null) {
          _addLog("User Created: ${res.user!.id}");
          
          if (referralCode.isNotEmpty) {
             _addLog("Processing Referral: $referralCode");
             await _processReferralCode(res.user!.id, referralCode);
          }
          
          _addLog("✅ Process Complete. Switch to Login.");
          _showSnackBar('Account created! Please Login.', Colors.green);
          setState(() {
            _isLoginMode = true;
            _referralController.clear();
            _passwordController.clear();
          });
        } else {
           _addLog("⚠️ Warning: User object is null after signup.");
        }
      }
    } on AuthException catch (e) {
      _addLog("🛑 Supabase Auth Error: ${e.message}");
      _addLog("Status Code: ${e.statusCode}");
    } catch (e) {
      _addLog("🛑 Unexpected Error: $e");
    } finally {
      setState(() => _isLoading = false);
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
        _addLog("Referral Linked Successfully.");
      } else {
        _addLog("Invalid Referral Code.");
      }
    } catch (e) {
      _addLog("Referral Logic Error: $e");
    }
  }

  // ==========================================
  // 3. GOOGLE SIGN-IN LOGIC (DIAGNOSTIC)
  // ==========================================
  Future<void> _googleSignIn() async {
    _addLog("🚀 Google Sign-In Started...");
    setState(() => _isLoading = true);
    try {
      // Is Web Client ID ko replace mat karna
      const webClientId = '567470905268-sh82ku8hkh0t50gl6pf4ob4p90d6kc0d.apps.googleusercontent.com';

      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: null, 
        serverClientId: webClientId,
      );

      _addLog("Step 1: Launching Google Popup...");
      final googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        _addLog("⚠️ User Cancelled Google Login.");
        setState(() => _isLoading = false);
        return; 
      }
      _addLog("Google User Selected: ${googleUser.email}");

      _addLog("Step 2: Retrieving Tokens...");
      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      _addLog("🔑 Access Token: ${accessToken != null ? 'OK' : 'NULL'}");
      _addLog("🔑 ID Token: ${idToken != null ? 'OK' : 'NULL'}");

      if (idToken == null) {
        _addLog("❌ FATAL ERROR: ID Token is NULL.");
        _addLog("👉 Check SHA-1 in Google Cloud Console.");
        throw 'ID Token Missing';
      }

      _addLog("Step 3: Authenticating with Supabase...");
      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      _addLog("✅ Supabase Login Success!");
      _navigateToHome();

    } on PlatformException catch (e) {
      _addLog("🛑 Platform Exception: ${e.code}");
      _addLog("Message: ${e.message}");
      if (e.code == 'sign_in_failed') {
         _addLog("👉 HINT: This is Error 10. Check SHA-1 & Support Email.");
      }
    } on AuthException catch (e) {
      _addLog("🛑 Supabase Rejected: ${e.message}");
    } catch (e) {
      _addLog("🛑 Crash: $e");
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
      body: Stack(
        children: [
          // --- MAIN BACKGROUND & CONTENT ---
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 250), // Bottom padding for logs
              child: Column(
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
                    style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 30),

                  // Input Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email Address',
                            prefixIcon: Icon(Icons.email_outlined, color: Colors.purple.shade300),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                          child: Text(_isLoginMode ? "Create Account" : "Login", style: const TextStyle(fontWeight: FontWeight.bold)),
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
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                      icon: const Icon(Icons.g_mobiledata, size: 40, color: Colors.red), 
                      label: Text('Sign in with Google', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- DEBUG CONSOLE (OVERLAY AT BOTTOM) ---
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 220,
              width: double.infinity,
              color: Colors.black.withOpacity(0.85),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("🛠️ DEBUG CONSOLE", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                      GestureDetector(
                        onTap: () => setState(() => _logs.clear()),
                        child: const Icon(Icons.delete, color: Colors.white54, size: 20),
                      )
                    ],
                  ),
                  const Divider(color: Colors.greenAccent, height: 10),
                  Expanded(
                    child: _logs.isEmpty 
                      ? const Center(child: Text("Waiting for action...", style: TextStyle(color: Colors.white30)))
                      : ListView.builder(
                          itemCount: _logs.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Text(
                                _logs[index],
                                style: TextStyle(
                                  color: _logs[index].contains("✅") ? Colors.greenAccent 
                                       : _logs[index].contains("🛑") || _logs[index].contains("❌") ? Colors.redAccent 
                                       : _logs[index].contains("🔑") ? Colors.amberAccent
                                       : Colors.white,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            );
                          },
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}