import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_constants.dart'; // Constants file import ki
// Login screen importimport
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
        colorSchemeSeed: Colors.blue, // Modern Theme Color
      ),
      //home: const LoginScreen(), // App yahan se shuru hoga
      home: const HomeScreen(),
    );
  }
}