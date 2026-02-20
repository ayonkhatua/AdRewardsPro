import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminWithdrawalsPage extends StatefulWidget {
  const AdminWithdrawalsPage({super.key});

  @override
  State<AdminWithdrawalsPage> createState() => _AdminWithdrawalsPageState();
}

class _AdminWithdrawalsPageState extends State<AdminWithdrawalsPage> {
  final _supabase = Supabase.instance.client;
  
  // Track currently processing ID to show loading indicator on specific button
  int? _processingId; 

  // Status update karne ka function
  Future<void> _updateStatus(int id, String newStatus, String userId, int coinsToRefund) async {
    setState(() => _processingId = id); // Loading shuru
    
    try {
      // 1. Withdrawal table mein status update karo ('paid' ya 'rejected')
      await _supabase.from('withdrawals').update({'status': newStatus}).eq('id', id);

      // 2. Agar reject kiya hai, toh user ko uske coins wapas (refund) kar do
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
          const SnackBar(content: Text('❌ Failed to update status. Check Supabase RLS policies.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _processingId = null); // Loading khatam
    }
  }

  // Time format karne ka function
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Withdrawal Requests', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF6A11CB))),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            // Naye requests upar dikhenge
            stream: _supabase.from('withdrawals').stream(primaryKey: ['id']).order('created_at', ascending: false),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF6A11CB)));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_rounded, size: 60, color: Colors.grey.shade300),
                      const SizedBox(height: 10),
                      const Text('No pending requests', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                );
              }

              final requests = snapshot.data!;

              return ListView.builder(
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final req = requests[index];
                  final isPending = req['status'] == 'pending';
                  final reqId = req['id'];
                  final isProcessingThis = _processingId == reqId;

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: isPending ? 3 : 1,
                    color: isPending ? Colors.orange.shade50 : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('UPI: ${req['upi_id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: req['status'] == 'paid' ? Colors.green.shade100 : 
                                         req['status'] == 'rejected' ? Colors.red.shade100 : Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  req['status'].toString().toUpperCase(), 
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: req['status'] == 'paid' ? Colors.green.shade800 : 
                                           req['status'] == 'rejected' ? Colors.red.shade800 : Colors.orange.shade800,
                                    fontWeight: FontWeight.bold
                                  )
                                ),
                              ),
                            ],
                          ),
                          const Divider(),
                          const SizedBox(height: 4),
                          
                          // 👇 NAYA: Yahan Time dikhega
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 16, color: Colors.grey),
                              const SizedBox(width: 6),
                              Text(_formatDateTime(req['created_at']), style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w500)),
                            ],
                          ),
                          const SizedBox(height: 8),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Amount: ₹${req['amount_in_rupees']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                              Text('${req['coins_deducted']} Coins', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          
                          // Action Buttons
                          if (isPending) ...[
                            const SizedBox(height: 12),
                            isProcessingThis 
                              ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: Color(0xFF6A11CB))))
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                                      icon: const Icon(Icons.cancel, size: 18),
                                      label: const Text('Reject'),
                                      onPressed: () => _updateStatus(reqId, 'rejected', req['user_id'], req['coins_deducted']),
                                    ),
                                    const SizedBox(width: 10),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                      icon: const Icon(Icons.check_circle, size: 18),
                                      label: const Text('Mark Paid'),
                                      onPressed: () => _updateStatus(reqId, 'paid', req['user_id'], 0),
                                    ),
                                  ],
                                )
                          ]
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