import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminWithdrawalsPage extends StatefulWidget {
  const AdminWithdrawalsPage({super.key});

  @override
  State<AdminWithdrawalsPage> createState() => _AdminWithdrawalsPageState();
}

class _AdminWithdrawalsPageState extends State<AdminWithdrawalsPage> {
  final _supabase = Supabase.instance.client;

  // Status update karne ka function
  Future<void> _updateStatus(int id, String newStatus, String userId, int coinsToRefund) async {
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
            content: Text('Payment marked as $newStatus!'), 
            backgroundColor: newStatus == 'paid' ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error updating status: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status'), backgroundColor: Colors.red),
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
          child: Text('Withdrawal Requests', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                return const Center(child: Text('No withdrawal requests found.'));
              }

              final requests = snapshot.data!;

              return ListView.builder(
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final req = requests[index];
                  final isPending = req['status'] == 'pending';

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: isPending ? Colors.orange.shade50 : Colors.white,
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text('UPI: ${req['upi_id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('Amount: ₹${req['amount_in_rupees']} (${req['coins_deducted']} Coins)'),
                          Text('Status: ${req['status'].toString().toUpperCase()}', 
                            style: TextStyle(
                              color: req['status'] == 'paid' ? Colors.green : 
                                     req['status'] == 'rejected' ? Colors.red : Colors.orange,
                              fontWeight: FontWeight.bold
                            )
                          ),
                        ],
                      ),
                      // Agar pending hai tabhi button dikhayenge
                      trailing: isPending ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Reject Button
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red, size: 30),
                            tooltip: 'Reject & Refund',
                            onPressed: () => _updateStatus(req['id'], 'rejected', req['user_id'], req['coins_deducted']),
                          ),
                          // Paid Button
                          IconButton(
                            icon: const Icon(Icons.check_circle, color: Colors.green, size: 30),
                            tooltip: 'Mark as Paid',
                            onPressed: () => _updateStatus(req['id'], 'paid', req['user_id'], 0),
                          ),
                        ],
                      ) : Icon(
                        req['status'] == 'paid' ? Icons.verified : Icons.error, 
                        color: req['status'] == 'paid' ? Colors.green : Colors.red
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