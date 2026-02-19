import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 👈 Naya: .env file ke liye
import 'package:unity_ads_plugin/unity_ads_plugin.dart'; // 👈 Naya: Unity Ads ke liye

// Screens import (Aapke folder structure ke hisaab se)
import 'screens/login_screen.dart'; 
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Sabse pehle .env file ko load karo
  await dotenv.load(fileName: ".env");

  // 2. .env file se secret keys nikalo
  final String supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final String supabaseKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  final String unityGameId = dotenv.env['UNITY_GAME_ID'] ?? '';

  // 3. Supabase initialize karo (Secure tareeke se)
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
  );

  // 4. Unity Ads initialize karo
  if (unityGameId.isNotEmpty) {
    UnityAds.init(
      gameId: unityGameId,
      testMode: true, // 👈 Abhi test mode true hai, app live jane pe false kar dena
      onComplete: () => debugPrint('✅ Unity Ads Initialization Complete'),
      onFailed: (error, message) => debugPrint('❌ Unity Ads Failed: $message'),
    );
  } else {
    debugPrint('⚠️ Error: Unity Game ID .env file mein nahi mili!');
  }

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
        colorSchemeSeed: const Color(0xFF6A11CB), 
      ),
      home: const AuthCheck(),
    );
  }
}

// ==========================================
// Auth Check Logic (Unchanged)
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