import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageUsersPage extends StatefulWidget {
  const ManageUsersPage({super.key});

  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
  final _supabase = Supabase.instance.client;
  
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  Future<void> _toggleBlockStatus(String userId, bool currentStatus) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(currentStatus ? Icons.lock_open : Icons.block, color: currentStatus ? Colors.green : Colors.red),
            const SizedBox(width: 8),
            Text(currentStatus ? 'Unblock User?' : 'Block User?'),
          ],
        ),
        content: Text(currentStatus 
            ? 'Are you sure you want to unblock this user? They will be able to use the app again.' 
            : 'Are you sure you want to block this user? They will lose access to the app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: currentStatus ? Colors.green : Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(currentStatus ? 'Unblock' : 'Block', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error updating block status: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update user status'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
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
    // 👇 FIX 1: Scaffold add kiya taaki screen properly render ho
    return Scaffold(
      backgroundColor: const Color(0xFFFDF8FD),
      appBar: AppBar(
        title: const Text('Manage Users', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1D1B20),
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Real-time Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase(); 
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by Invite Code or ID...', // 👇 FIX 2: Text update kiya
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
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
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
                  return const Center(child: Text('No users found.', style: TextStyle(color: Colors.grey)));
                }

                List<Map<String, dynamic>> users = List<Map<String, dynamic>>.from(snapshot.data!);

                // 👇 FIX 2: Email ki jagah referral_code aur ID se search kiya
                if (_searchQuery.isNotEmpty) {
                  users = users.where((user) {
                    final refCode = (user['referral_code'] ?? '').toString().toLowerCase();
                    final id = (user['id'] ?? '').toString().toLowerCase();
                    return refCode.contains(_searchQuery) || id.contains(_searchQuery);
                  }).toList();
                }

                // Balance ke hisaab se sort
                users.sort((a, b) => (b['wallet_balance'] ?? 0).compareTo(a['wallet_balance'] ?? 0));

                if (users.isEmpty) {
                  return const Center(child: Text('No users match your search.', style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final bool isBlocked = user['is_blocked'] ?? false; 
                    final String refCode = user['referral_code'] ?? 'NO CODE'; // 👇 FIX 2: Email ki jagah Code

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isBlocked ? Colors.red.shade300 : Colors.transparent, 
                          width: 2
                        ),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: isBlocked ? Colors.red.shade100 : const Color(0xFFEADDFF),
                          child: Icon(
                            isBlocked ? Icons.block : Icons.person,
                            color: isBlocked ? Colors.red : const Color(0xFF6A11CB),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Code: $refCode", // 👇 FIX 2: UI mein Referral Code
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text('ID: ${user['id'].toString().substring(0, 8)}...', style: const TextStyle(fontSize: 12)),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isBlocked ? Colors.red.shade50 : Colors.green.shade50, 
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: isBlocked ? Colors.red.shade200 : Colors.green.shade200)
                              ),
                              child: Text(
                                '${user['wallet_balance'] ?? 0} Coins', 
                                style: TextStyle(
                                  color: isBlocked ? Colors.red : Colors.green.shade700, 
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12
                                )
                              ),
                            ),
                            const SizedBox(width: 8),
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
      ),
    );
  }
}