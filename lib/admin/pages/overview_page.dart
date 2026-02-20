import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  // Sabhi users ka data ek hi baar laayenge taaki app fast rahe
  Future<Map<String, List<Map<String, dynamic>>>> _getUsersData() async {
    final response = await Supabase.instance.client
        .from('profiles')
        .select('id, email, is_blocked, wallet_balance, referral_code');
        
    final List<Map<String, dynamic>> allUsers = List<Map<String, dynamic>>.from(response);

    // Filter kar rahe hain
    final activeUsers = allUsers.where((u) => u['is_blocked'] != true).toList();
    final blockedUsers = allUsers.where((u) => u['is_blocked'] == true).toList();

    return {
      'all': allUsers,
      'active': activeUsers,
      'blocked': blockedUsers,
    };
  }

  // Card UI banane ka reusable function
  Widget _buildStatCard({
    required String title,
    required int count,
    required IconData icon,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: gradientColors.last.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 36),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
                  Text('$count', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
      future: _getUsersData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF6A11CB)));
        }
        
        if (snapshot.hasError) {
          return Center(child: Text("Error loading stats: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
        }

        final data = snapshot.data!;
        final totalUsers = data['all']!;
        final activeUsers = data['active']!;
        final blockedUsers = data['blocked']!;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome, Admin! 👑', style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: const Color(0xFF1D1B20))),
              const SizedBox(height: 8),
              const Text('Here is what is happening in your app today.', style: TextStyle(color: Colors.grey, fontSize: 16)),
              const SizedBox(height: 30),

              // 1. Total Registered Card
              _buildStatCard(
                title: 'Total Registered',
                count: totalUsers.length,
                icon: Icons.people_alt_rounded,
                gradientColors: [const Color(0xFF6A11CB), const Color(0xFF2575FC)],
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => FilteredUsersScreen(title: 'All Registered Users', users: totalUsers, themeColor: const Color(0xFF6A11CB))
                )),
              ),

              // 2. Active Users Card
              _buildStatCard(
                title: 'Total Active Users',
                count: activeUsers.length,
                icon: Icons.verified_user_rounded,
                gradientColors: [const Color(0xFF11998E), const Color(0xFF38EF7D)],
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => FilteredUsersScreen(title: 'Active Users', users: activeUsers, themeColor: const Color(0xFF11998E))
                )),
              ),

              // 3. Blocked Users Card
              _buildStatCard(
                title: 'Total Blocked',
                count: blockedUsers.length,
                icon: Icons.block_flipped,
                gradientColors: [const Color(0xFFFF416C), const Color(0xFFFF4B2B)],
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => FilteredUsersScreen(title: 'Blocked Users', users: blockedUsers, themeColor: const Color(0xFFFF416C))
                )),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ==========================================
// NAYA SCREEN: Click karne par Users ki List dikhane ke liye
// ==========================================
class FilteredUsersScreen extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> users;
  final Color themeColor;

  const FilteredUsersScreen({
    super.key, 
    required this.title, 
    required this.users, 
    required this.themeColor
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFFDF8FD),
      body: users.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_rounded, size: 60, color: Colors.grey.shade400),
                  const SizedBox(height: 10),
                  const Text('No users found in this category.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final String userEmail = user['email'] ?? 'No Email Provided';
                final bool isBlocked = user['is_blocked'] ?? false;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: isBlocked ? Colors.red.shade200 : Colors.transparent),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: themeColor.withOpacity(0.1),
                      child: Icon(
                        isBlocked ? Icons.block : Icons.person, 
                        color: isBlocked ? Colors.red : themeColor
                      ),
                    ),
                    title: Text(userEmail, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('ID: ${user['id'].toString().substring(0, 8)}...\nCoins: ${user['wallet_balance'] ?? 0}'),
                    isThreeLine: true,
                    trailing: isBlocked 
                      ? const Text('BLOCKED', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12))
                      : const Text('ACTIVE', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                );
              },
            ),
    );
  }
}