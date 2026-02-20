import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSupportPage extends StatefulWidget {
  const AdminSupportPage({super.key});

  @override
  State<AdminSupportPage> createState() => _AdminSupportPageState();
}

class _AdminSupportPageState extends State<AdminSupportPage> {
  final _supabase = Supabase.instance.client;
  int? _processingId;

  // Ticket ko Resolve (Close) karne ka function
  Future<void> _resolveTicket(int id) async {
    setState(() => _processingId = id);
    try {
      await _supabase.from('support_tickets').update({'status': 'resolved'}).eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Ticket Marked as Resolved!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Error resolving ticket: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Failed to update status.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _processingId = null);
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

  // Category ke hisaab se color return karna
  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Payment Issue': return Colors.orange;
      case 'Bug / App Crash': return Colors.red;
      case 'Account Problem': return Colors.blue;
      case 'Suggestion / Review': return Colors.green;
      default: return Colors.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Support Inbox', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF6A11CB))),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            // Sirf 'open' tickets dikhayenge, jo naye hain
            stream: _supabase.from('support_tickets').stream(primaryKey: ['id']).eq('status', 'open').order('created_at', ascending: false),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF6A11CB)));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mark_email_read_rounded, size: 60, color: Colors.grey.shade300),
                      const SizedBox(height: 10),
                      const Text('Inbox is empty. No pending tickets!', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                );
              }

              final tickets = snapshot.data!;

              return ListView.builder(
                itemCount: tickets.length,
                itemBuilder: (context, index) {
                  final ticket = tickets[index];
                  final isProcessing = _processingId == ticket['id'];
                  final catColor = _getCategoryColor(ticket['category']);

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Category Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: catColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: catColor.withOpacity(0.5)),
                                ),
                                child: Text(
                                  ticket['category'],
                                  style: TextStyle(color: catColor, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Text(_formatDateTime(ticket['created_at']), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          // Issue Title
                          Text(ticket['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 6),
                          
                          // Issue Description
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                            child: Text(ticket['description'], style: TextStyle(color: Colors.grey.shade800, fontSize: 14)),
                          ),
                          const SizedBox(height: 12),
                          
                          const Divider(),
                          
                          // Footer: Email & Action Button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.email, size: 16, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text(ticket['email'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF6A11CB))),
                                ],
                              ),
                              isProcessing 
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                                : ElevatedButton.icon(
                                    onPressed: () => _resolveTicket(ticket['id']),
                                    icon: const Icon(Icons.check, size: 16),
                                    label: const Text('Resolve'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green, 
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                      minimumSize: const Size(0, 36)
                                    ),
                                  )
                            ],
                          )
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