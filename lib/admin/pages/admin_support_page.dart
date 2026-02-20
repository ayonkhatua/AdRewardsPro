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

  // 👇 NAYA: Ticket ka status update karne ka Master Function
  Future<void> _updateTicketStatus(int id, String newStatus) async {
    setState(() => _processingId = id);
    try {
      await _supabase.from('support_tickets').update({'status': newStatus}).eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus == 'resolved' ? '✅ Ticket Marked as Resolved!' : '❌ Ticket Rejected!'), 
            backgroundColor: newStatus == 'resolved' ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error updating ticket: $e");
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
            // Sirf 'open' (naye) tickets dikhayenge
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
                  final ticketId = ticket['id'];
                  final isProcessing = _processingId == ticketId;
                  final catColor = _getCategoryColor(ticket['category']);

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 3,
                    color: Colors.orange.shade50, // Naye ticket ko thoda highlight karne ke liye
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
                              Row(
                                children: [
                                  const Icon(Icons.access_time_rounded, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(_formatDateTime(ticket['created_at']), style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          // Issue Title
                          Text(ticket['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 6),
                          
                          // Issue Description
                          Container(
                            padding: const EdgeInsets.all(12),
                            width: double.infinity,
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                            child: Text(ticket['description'], style: TextStyle(color: Colors.grey.shade800, fontSize: 14)),
                          ),
                          const SizedBox(height: 12),
                          
                          const Divider(),
                          
                          // Footer: Email
                          Row(
                            children: [
                              const Icon(Icons.email, size: 16, color: Colors.grey),
                              const SizedBox(width: 6),
                              Text(ticket['email'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF6A11CB))),
                            ],
                          ),
                          
                          const SizedBox(height: 12),

                          // 👇 NAYA: Action Buttons (Reject & Resolve)
                          isProcessing 
                            ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: Color(0xFF6A11CB))))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _updateTicketStatus(ticketId, 'rejected'),
                                    icon: const Icon(Icons.cancel, size: 16),
                                    label: const Text('Reject'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red, 
                                      side: const BorderSide(color: Colors.red),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                      minimumSize: const Size(0, 36)
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton.icon(
                                    onPressed: () => _updateTicketStatus(ticketId, 'resolved'),
                                    icon: const Icon(Icons.check_circle, size: 16),
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