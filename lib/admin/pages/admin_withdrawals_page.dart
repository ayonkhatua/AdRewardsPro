import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart'; // 👇 NAYA: Copy function ke liye import kiya

class AdminWithdrawalsPage extends StatefulWidget {
  const AdminWithdrawalsPage({super.key});

  @override
  State<AdminWithdrawalsPage> createState() => _AdminWithdrawalsPageState();
}

class _AdminWithdrawalsPageState extends State<AdminWithdrawalsPage> {
  final _supabase = Supabase.instance.client;
  
  int? _processingId; 
  
  // 👇 NAYA: Database se baar-baar email na mangna pade isliye Cache banaya
  final Map<String, String> _emailCache = {};

  Future<String> _getUserEmail(String userId) async {
    if (_emailCache.containsKey(userId)) return _emailCache[userId]!;
    try {
      final res = await _supabase.from('profiles').select('email').eq('id', userId).single();
      _emailCache[userId] = res['email'] ?? 'No Email Provided';
      return _emailCache[userId]!;
    } catch (e) {
      return 'Unknown Email';
    }
  }

  Future<void> _updateStatus(int id, String newStatus, String userId, int coinsToRefund) async {
    setState(() => _processingId = id); 
    
    try {
      await _supabase.from('withdrawals').update({'status': newStatus}).eq('id', id);

      if (newStatus == 'rejected') {
        final userData = await _supabase.from('profiles').select('wallet_balance').eq('id', userId).single();
        final currentBalance = userData['wallet_balance'] ?? 0;
        
        await _supabase.from('profiles').update({
          'wallet_balance': currentBalance + coinsToRefund
        }).eq('id', userId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Payment marked as ${newStatus.toUpperCase()}!'), 
            backgroundColor: newStatus == 'paid' ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error updating status: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Failed to update status.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _processingId = null); 
    }
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null) return "Unknown Time";
    try {
      final DateTime dt = DateTime.parse(isoString).toLocal();
      final String ampm = dt.hour >= 12 ? 'PM' : 'AM';
      int hour12 = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      
      String day = dt.day.toString().padLeft(2, '0');
      String month = dt.month.toString().padLeft(2, '0');
      String year = dt.year.toString();
      String hrs = hour12.toString().padLeft(2, '0');
      String mins = dt.minute.toString().padLeft(2, '0');
      
      return "$day-$month-$year at $hrs:$mins $ampm";
    } catch (e) {
      return "Invalid Time";
    }
  }

  // 👇 NAYA: User History dikhane ka function
  void _showUserHistory(String userId, String userEmail) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7, // 70% screen lega
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF6A11CB).withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.history_rounded, color: Color(0xFF6A11CB)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("User History", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF6A11CB))),
                          Text(userEmail, style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  // Is user ki saari transactions laa rahe hain
                  future: _supabase.from('withdrawals').select().eq('user_id', userId).order('created_at', ascending: false),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF6A11CB)));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text("No transaction history found."));
                    }

                    final history = snapshot.data!;
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final h = history[index];
                        final status = h['status'].toString().toLowerCase();
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 1,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: status == 'paid' ? Colors.green.shade100 : (status == 'rejected' ? Colors.red.shade100 : Colors.orange.shade100),
                              child: Icon(
                                status == 'paid' ? Icons.check_circle : (status == 'rejected' ? Icons.cancel : Icons.access_time),
                                color: status == 'paid' ? Colors.green : (status == 'rejected' ? Colors.red : Colors.orange),
                              ),
                            ),
                            title: Text("₹${h['amount_in_rupees']} - ${h['upi_id']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(_formatDateTime(h['created_at']), style: const TextStyle(fontSize: 12)),
                            trailing: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: status == 'paid' ? Colors.green : (status == 'rejected' ? Colors.red : Colors.orange),
                              ),
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Pending Requests', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF6A11CB))),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            // 👇 NAYA: ".eq('status', 'pending')" lagaya taaki sirf pending requests dikhein
            stream: _supabase.from('withdrawals').stream(primaryKey: ['id']).eq('status', 'pending').order('created_at', ascending: false),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF6A11CB)));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 60, color: Colors.green.shade300),
                      const SizedBox(height: 10),
                      const Text('All caught up! No pending requests.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                );
              }

              final requests = snapshot.data!;

              return ListView.builder(
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final req = requests[index];
                  final reqId = req['id'];
                  final userId = req['user_id'];
                  final isProcessingThis = _processingId == reqId;

                  return FutureBuilder<String>(
                    future: _getUserEmail(userId), // 👈 Email fetch kar rahe hain
                    builder: (context, emailSnapshot) {
                      final userEmail = emailSnapshot.data ?? "Loading email...";

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        elevation: 3,
                        color: Colors.orange.shade50,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        // 👇 NAYA: Card par click karne se History khulegi
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _showUserHistory(userId, userEmail),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('PENDING', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                    Row(
                                      children: [
                                        const Icon(Icons.access_time_rounded, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(_formatDateTime(req['created_at']), style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                                      ],
                                    ),
                                  ],
                                ),
                                const Divider(),
                                const SizedBox(height: 4),
                                
                                // Amount aur UPI
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('₹${req['amount_in_rupees']}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                                    Text('${req['coins_deducted']} Coins', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                
                                // 👇 NAYA: Copy button add kiya gaya hai
                                Row(
                                  children: [
                                    const Icon(Icons.account_balance, size: 16, color: Color(0xFF6A11CB)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(req['upi_id'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 18, color: Colors.grey),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: "Copy",
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: req['upi_id'].toString()));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text("Copied!"), 
                                            duration: Duration(seconds: 1),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.email, size: 16, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text(userEmail, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                                  ],
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Action Buttons
                                isProcessingThis 
                                  ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: Color(0xFF6A11CB))))
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                                          icon: const Icon(Icons.cancel, size: 18),
                                          label: const Text('Reject'),
                                          onPressed: () => _updateStatus(reqId, 'rejected', userId, req['coins_deducted']),
                                        ),
                                        const SizedBox(width: 10),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                          icon: const Icon(Icons.check_circle, size: 18),
                                          label: const Text('Mark Paid'),
                                          onPressed: () => _updateStatus(reqId, 'paid', userId, 0),
                                        ),
                                      ],
                                    )
                              ],
                            ),
                          ),
                        ),
                      );
                    }
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