import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageUsersPage extends StatefulWidget {
  const ManageUsersPage({super.key});

  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
  final _supabase = Supabase.instance.client;

  // 👇 Block/Unblock toggle karne ka function
  Future<void> _toggleBlockStatus(String userId, bool currentStatus) async {
    // Confirmation dialog dikhayenge pehle
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(currentStatus ? 'Unblock User?' : 'Block User?'),
        content: Text(currentStatus 
            ? 'Are you sure you want to unblock this user? They will be able to use the app again.' 
            : 'Are you sure you want to block this user? They will lose access to the app.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: currentStatus ? Colors.green : Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(currentStatus ? 'Unblock' : 'Block', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      // Supabase mein update kar rahe hain
      await _supabase.from('profiles').update({
        'is_blocked': !currentStatus,
      }).eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(currentStatus ? '✅ User Unblocked Successfully' : '🚫 User Blocked Successfully'),
            backgroundColor: currentStatus ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error updating block status: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update user status'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('All Users Database', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          // 👇 NAYA: FutureBuilder ki jagah StreamBuilder lagaya taaki Live (Real-time) update ho
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _supabase.from('profiles').stream(primaryKey: ['id']),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF6A11CB)));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No users found.'));
              }

              // Data ko sort kar rahe hain (Highest balance upar)
              final users = List<Map<String, dynamic>>.from(snapshot.data!);
              users.sort((a, b) => (b['wallet_balance'] ?? 0).compareTo(a['wallet_balance'] ?? 0));

              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  final bool isBlocked = user['is_blocked'] ?? false; // Check block status

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: isBlocked ? Colors.red.shade50 : Colors.white, // Blocked user ka card laal ho jayega
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: isBlocked ? Colors.red.shade300 : Colors.transparent),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isBlocked ? Colors.red.shade100 : const Color(0xFFEADDFF),
                        child: Text(
                          user['referral_code']?.substring(0, 1) ?? 'U',
                          style: TextStyle(color: isBlocked ? Colors.red : const Color(0xFF6A11CB), fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Row(
                        children: [
                          Text('Ref: ${user['referral_code'] ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          if (isBlocked) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.block, color: Colors.red, size: 16),
                          ]
                        ],
                      ),
                      subtitle: Text('ID: ${user['id'].toString().substring(0, 8)}...'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Coins Box
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isBlocked ? Colors.red.shade100 : Colors.green.shade100, 
                              borderRadius: BorderRadius.circular(20)
                            ),
                            child: Text(
                              '${user['wallet_balance'] ?? 0} Coins', 
                              style: TextStyle(
                                color: isBlocked ? Colors.red : Colors.green, 
                                fontWeight: FontWeight.bold
                              )
                            ),
                          ),
                          const SizedBox(width: 8),
                          
                          // 👇 Block/Unblock Button
                          IconButton(
                            icon: Icon(
                              isBlocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                              color: isBlocked ? Colors.green : Colors.red,
                            ),
                            tooltip: isBlocked ? 'Unblock User' : 'Block User',
                            onPressed: () => _toggleBlockStatus(user['id'], isBlocked),
                          ),
                        ],
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