import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageUsersPage extends StatefulWidget {
  const ManageUsersPage({super.key});

  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
  final _supabase = Supabase.instance.client;
  
  // 👇 NAYA: Search query track karne ke liye variable
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  Future<void> _toggleBlockStatus(String userId, bool currentStatus) async {
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('All Users Database', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        
        // 👇 NAYA: Real-time Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase(); // Search query update hogi
              });
            },
            decoration: InputDecoration(
              hintText: 'Search by Email or User ID...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF6A11CB)),
              suffixIcon: _searchQuery.isNotEmpty 
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  ) 
                : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF6A11CB), width: 2),
              ),
            ),
          ),
        ),

        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _supabase.from('profiles').stream(primaryKey: ['id']),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF6A11CB)));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No users found.'));
              }

              // Sabhi users ko le aaye
              List<Map<String, dynamic>> users = List<Map<String, dynamic>>.from(snapshot.data!);

              // 👇 NAYA: Search filter logic (Email ya ID se match karega)
              if (_searchQuery.isNotEmpty) {
                users = users.where((user) {
                  final email = (user['email'] ?? '').toString().toLowerCase();
                  final id = (user['id'] ?? '').toString().toLowerCase();
                  return email.contains(_searchQuery) || id.contains(_searchQuery);
                }).toList();
              }

              // Filter hone ke baad sort kar rahe hain (Highest balance upar)
              users.sort((a, b) => (b['wallet_balance'] ?? 0).compareTo(a['wallet_balance'] ?? 0));

              if (users.isEmpty) {
                return const Center(child: Text('No users match your search.', style: TextStyle(color: Colors.grey)));
              }

              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  final bool isBlocked = user['is_blocked'] ?? false; 
                  // 👇 Email show karne ke liye
                  final String userEmail = user['email'] ?? 'No Email Provided';

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: isBlocked ? Colors.red.shade50 : Colors.white, 
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: isBlocked ? Colors.red.shade300 : Colors.transparent),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isBlocked ? Colors.red.shade100 : const Color(0xFFEADDFF),
                        child: Text(
                          userEmail != 'No Email Provided' ? userEmail.substring(0, 1).toUpperCase() : 'U',
                          style: TextStyle(color: isBlocked ? Colors.red : const Color(0xFF6A11CB), fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Row(
                        children: [
                          // 👇 NAYA: Referral Code ki jagah Email aa gaya
                          Expanded(
                            child: Text(
                              userEmail, 
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis, // Bada email ho toh cut ho jaye
                            ),
                          ),
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
                          
                          // Block/Unblock Button
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