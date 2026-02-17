import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_constants.dart'; // Constants file import ki

// Screens import (Aapke folder structure ke hisaab se)
import 'screens/login_screen.dart'; 
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Yahan humne Constants file use ki
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ad Rewards Pro',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF6A11CB), // Thoda app se match karta hua theme color
      ),
      // Ab yahan direct Home ya Login nahi de rahe, balki AuthCheck ko bulayenge
      home: const AuthCheck(),
    );
  }
}

// ==========================================
// NAYA: Auth Check Logic
// ==========================================
class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    // Supabase ka current session check karte hain
    final session = Supabase.instance.client.auth.currentSession;

    // Agar session null nahi hai (matlab user login hai), toh Home Screen dikhao
    if (session != null) {
      return const HomeScreen();
    } else {
      // Warna naye user ko Login Screen dikhao
      return const LoginScreen();
    }
  }
}