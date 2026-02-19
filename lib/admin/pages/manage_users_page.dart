import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageUsersPage extends StatelessWidget {
  const ManageUsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('All Users Database', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: FutureBuilder(
            future: supabase.from('profiles').select().order('wallet_balance', ascending: false),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || (snapshot.data as List).isEmpty) {
                return const Center(child: Text('No users found.'));
              }

              final users = snapshot.data as List<dynamic>;

              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFEADDFF),
                        child: Text(user['referral_code']?.substring(0, 1) ?? 'U'),
                      ),
                      title: Text('Ref Code: ${user['referral_code']}'),
                      subtitle: Text('ID: ${user['id'].toString().substring(0, 8)}...'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(20)),
                        child: Text('${user['wallet_balance']} Coins', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}