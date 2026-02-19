import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TransactionScreen extends StatelessWidget {
  const TransactionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8FD),
      appBar: AppBar(
        title: const Text('Transactions'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: userId == null
          ? const Center(child: Text("Please login to view transactions"))
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client
                  .from('withdrawals')
                  .stream(primaryKey: ['id'])
                  .eq('user_id', userId)
                  .order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF6750A4)));
                }
                
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_rounded, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text("No transactions yet", style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                  );
                }

                final transactions = snapshot.data!;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    final amount = tx['amount_in_rupees'] ?? 0;
                    final status = tx['status'] ?? 'pending';
                    final upi = tx['upi_id'] ?? 'Unknown UPI';
                    final coins = tx['coins_deducted'] ?? 0;

                    Color statusColor;
                    IconData statusIcon;
                    
                    switch (status.toString().toLowerCase()) {
                      case 'paid':
                      case 'success':
                        statusColor = Colors.green;
                        statusIcon = Icons.check_circle_rounded;
                        break;
                      case 'rejected':
                      case 'failed':
                        statusColor = Colors.red;
                        statusIcon = Icons.cancel_rounded;
                        break;
                      default:
                        statusColor = Colors.orange;
                        statusIcon = Icons.access_time_filled_rounded;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(statusIcon, color: statusColor),
                        ),
                        title: Text("₹$amount Withdrawal", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text("$upi\n${status.toUpperCase()}", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text("-$coins", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                            const Text("Coins", style: TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}