import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});

  Future<int> _getTotalUsers() async {
    final response = await Supabase.instance.client.from('profiles').select('id');
    return (response as List).length;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _getTotalUsers(),
      builder: (context, snapshot) {
        int totalUsers = snapshot.data ?? 0;

        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome, Admin! 👑', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF6A11CB))),
              const SizedBox(height: 10),
              const Text('Here is what is happening in your app today.', style: TextStyle(color: Colors.grey, fontSize: 16)),
              const SizedBox(height: 30),

              // Stats Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6A11CB), Color(0xFF2575FC)]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 5))],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.people_alt, color: Colors.white, size: 40),
                    const SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Registered Users', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        Text('$totalUsers', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}