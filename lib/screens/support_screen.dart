import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  
  bool _isLoading = false;
  String _userEmail = 'Loading...';
  
  // Dropdown Categories
  String _selectedCategory = 'Payment Issue';
  final List<String> _categories = [
    'Payment Issue',
    'Bug / App Crash',
    'Account Problem',
    'Suggestion / Review',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // 2 Tabs banaye
    _fetchUserEmail();
  }

  void _fetchUserEmail() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      setState(() {
        _userEmail = user.email ?? 'No Email Found';
      });
    }
  }

  Future<void> _submitTicket() async {
    final title = _titleController.text.trim();
    final desc = _descController.text.trim();

    if (title.isEmpty || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      
      if (user != null) {
        await Supabase.instance.client.from('support_tickets').insert({
          'user_id': user.id,
          'email': _userEmail,
          'title': title,
          'category': _selectedCategory,
          'description': desc,
          'status': 'open', // Default status
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Request Sent Successfully!'), backgroundColor: Colors.green),
          );
          // Ticket bhejte hi fields clear karo aur History tab (index 1) par bhej do
          _titleController.clear();
          _descController.clear();
          _tabController.animateTo(1); 
        }
      }
    } catch (e) {
      debugPrint("Support Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Error submitting request. Try again.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return "${dt.day}/${dt.month}/${dt.year}";
    } catch (e) {
      return "Unknown Date";
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF8FD),
      appBar: AppBar(
        title: Text('Help & Support', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1D1B20),
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF6A11CB),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF6A11CB),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: "New Request"),
            Tab(text: "My History"),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            // TAB 1: FORM BANANE KE LIYE
            _buildNewRequestTab(),
            
            // TAB 2: HISTORY DIKHANE KE LIYE
            _buildHistoryTab(),
          ],
        ),
      ),
    );
  }

  // =====================================
  // UI: NEW REQUEST FORM TAB
  // =====================================
  Widget _buildNewRequestTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(color: Color(0xFFEADDFF), shape: BoxShape.circle),
                  child: const Icon(Icons.support_agent_rounded, size: 60, color: Color(0xFF6A11CB)),
                ),
                const SizedBox(height: 16),
                Text("How can we help you?", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF1D1B20))),
                const SizedBox(height: 8),
                const Text("Send us a message and we will get back to you.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // 1. Email Box
          const Text("Your Email", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1D1B20))),
          const SizedBox(height: 8),
          TextField(
            controller: TextEditingController(text: _userEmail),
            readOnly: true,
            style: const TextStyle(color: Colors.grey),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey.shade200,
              prefixIcon: const Icon(Icons.email, color: Colors.grey),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 20),

          // 2. Dropdown
          const Text("Select Category", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1D1B20))),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCategory,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6A11CB)),
                items: _categories.map((String category) {
                  return DropdownMenuItem<String>(value: category, child: Text(category, style: const TextStyle(fontWeight: FontWeight.w500)));
                }).toList(),
                onChanged: (String? newValue) => setState(() => _selectedCategory = newValue!),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 3. Title
          const Text("Issue Title", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1D1B20))),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              filled: true, fillColor: Colors.white, hintText: "e.g., Payment not received",
              prefixIcon: const Icon(Icons.title_rounded, color: Color(0xFF6A11CB)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6A11CB), width: 2)),
            ),
          ),
          const SizedBox(height: 20),

          // 4. Description
          const Text("Description", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1D1B20))),
          const SizedBox(height: 8),
          TextField(
            controller: _descController,
            maxLines: 5,
            decoration: InputDecoration(
              filled: true, fillColor: Colors.white, hintText: "Please describe your issue in detail...",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6A11CB), width: 2)),
            ),
          ),
          const SizedBox(height: 30),

          // 5. Submit Button
          SizedBox(
            width: double.infinity, height: 55,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitTicket,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A11CB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 3,
              ),
              child: _isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                  : const Text("Submit Request", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================
  // UI: HISTORY TAB (StreamBuilder)
  // =====================================
  Widget _buildHistoryTab() {
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId == null) return const Center(child: Text("Please login to see history."));

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('support_tickets')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF6A11CB)));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_rounded, size: 60, color: Colors.grey.shade300),
                const SizedBox(height: 10),
                const Text("No previous requests found.", style: TextStyle(color: Colors.grey, fontSize: 16)),
              ],
            ),
          );
        }

        final tickets = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tickets.length,
          itemBuilder: (context, index) {
            final ticket = tickets[index];
            final status = ticket['status'].toString().toLowerCase(); // e.g., open, resolved, rejected
            
            Color statusColor;
            IconData statusIcon;

            // Status ke hisab se Color aur Icon badalna
            if (status == 'resolved' || status == 'closed') {
              statusColor = Colors.green;
              statusIcon = Icons.check_circle_rounded;
            } else if (status == 'rejected') {
              statusColor = Colors.red;
              statusIcon = Icons.cancel_rounded;
            } else {
              statusColor = Colors.orange;
              statusIcon = Icons.access_time_filled_rounded;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(ticket['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(ticket['category'], style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(_formatDate(ticket['created_at']), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        status == 'open' ? 'PENDING' : status.toUpperCase(), 
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}