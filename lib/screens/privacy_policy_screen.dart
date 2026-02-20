import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1D1B20)),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(fontSize: 14, color: Color(0xFF49454F), height: 1.6),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF8FD),
      appBar: AppBar(
        title: Text('Privacy Policy', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1D1B20),
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      const Icon(Icons.privacy_tip_rounded, size: 60, color: Color(0xFF6A11CB)),
                      const SizedBox(height: 16),
                      Text("Privacy Policy", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF6A11CB))),
                      const SizedBox(height: 4),
                      const Text("Effective Date: 20 February 2026", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                const Divider(),
                const SizedBox(height: 20),

                _buildSection("1. Introduction", "Welcome to AdRewards Pro. We are committed to protecting your privacy. This Privacy Policy explains how we collect, use, and safeguard your information when you use our mobile application."),
                _buildSection("2. Information We Collect", "• Account Information: Email Address for authentication.\n• Fraud Prevention Data: Device ID and IP Address strictly to prevent cheating.\n• Payment Information: UPI ID solely for processing your withdrawal payments."),
                _buildSection("3. How We Use Your Information", "We use your data to create and manage your account, track your coin balance, process withdrawals, serve advertisements, and prevent fraudulent activities on our platform."),
                _buildSection("4. Third-Party Services", "Our app uses third-party services like Supabase (for secure backend and authentication) and Unity Ads (to display advertisements). These services have their own Privacy Policies and may collect data to serve ads."),
                _buildSection("5. Data Retention & Deletion", "We keep your data as long as your account is active. You can permanently delete your account and all associated data directly from the 'Profile' section by clicking the 'Delete Account' button."),
                _buildSection("6. Security", "We value your trust and strive to use commercially acceptable means of protecting your data. However, remember that no method of transmission over the internet is 100% secure."),
                _buildSection("7. Contact Us", "If you have any questions or suggestions about our Privacy Policy, do not hesitate to contact us at:\n\nhyperstoreteam07@gmail.com"),
                
                const SizedBox(height: 20),
                Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEADDFF),
                      foregroundColor: const Color(0xFF6A11CB),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("I Understand"),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}