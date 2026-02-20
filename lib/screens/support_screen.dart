import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
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
          'status': 'open', // Default status for admin to check later
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Support Request Sent Successfully!'), backgroundColor: Colors.green),
          );
          Navigator.pop(context); // Ticket submit hone ke baad wapas pichle page par bhej do
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

  @override
  void dispose() {
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Image/Icon
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEADDFF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.support_agent_rounded, size: 60, color: Color(0xFF6A11CB)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "How can we help you?",
                      style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF1D1B20)),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Send us a message and we will get back to you as soon as possible.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // 1. Fixed Email Box (Can't edit)
              const Text("Your Email", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1D1B20))),
              const SizedBox(height: 8),
              TextField(
                controller: TextEditingController(text: _userEmail),
                readOnly: true, // User ise change nahi kar sakta
                style: const TextStyle(color: Colors.grey),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade200,
                  prefixIcon: const Icon(Icons.email, color: Colors.grey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),

              // 2. Select Category Dropdown
              const Text("Select Category", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1D1B20))),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6A11CB)),
                    items: _categories.map((String category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category, style: const TextStyle(fontWeight: FontWeight.w500)),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedCategory = newValue!;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 3. Issue Title
              const Text("Issue Title", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1D1B20))),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: "e.g., Payment not received",
                  prefixIcon: const Icon(Icons.title_rounded, color: Color(0xFF6A11CB)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6A11CB), width: 2)),
                ),
              ),
              const SizedBox(height: 20),

              // 4. Description Box
              const Text("Description", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1D1B20))),
              const SizedBox(height: 8),
              TextField(
                controller: _descController,
                maxLines: 5,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: "Please describe your issue in detail...",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6A11CB), width: 2)),
                ),
              ),
              const SizedBox(height: 30),

              // 5. Submit Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitTicket,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A11CB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 3,
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                      : const Text("Submit Request", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}