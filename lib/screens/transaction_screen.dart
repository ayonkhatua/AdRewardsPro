import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TransactionScreen extends StatelessWidget {
  const TransactionScreen({super.key});

  // 👇 NAYA: Date format karne ka helper function add kiya
  String _formatDateTime(String? isoString) {
    if (isoString == null) return "Unknown Date";
    try {
      final DateTime dt = DateTime.parse(isoString).toLocal();
      final String ampm = dt.hour >= 12 ? 'PM' : 'AM';
      int hour12 = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      
      String day = dt.day.toString().padLeft(2, '0');
      String month = dt.month.toString().padLeft(2, '0');
      String year = dt.year.toString();
      String hrs = hour12.toString().padLeft(2, '0');
      String mins = dt.minute.toString().padLeft(2, '0');
      
      return "$day-$month-$year • $hrs:$mins $ampm";
    } catch (e) {
      return "Invalid Date";
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8FD),
      appBar: AppBar(
        title: const Text('Transactions', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1D1B20),
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
                    final upi = tx['upi_id'] ?? 'Unknown Account';
                    final coins = tx['coins_deducted'] ?? 0;
                    
                    // 👇 NAYA: Date string fetch kar rahe hain
                    final dateString = _formatDateTime(tx['created_at']);

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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(statusIcon, color: statusColor, size: 28),
                        ),
                        title: Text("₹$amount Withdrawal", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        
                        // 👇 NAYA: Subtitle ko Column banaya taaki Date, UPI aur Status achhe se fit ho
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(upi, style: TextStyle(fontSize: 13, color: Colors.grey.shade800, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 3),
                              Text(dateString, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text("-$coins", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
                            const Text("Coins", style: TextStyle(fontSize: 11, color: Colors.grey)),
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