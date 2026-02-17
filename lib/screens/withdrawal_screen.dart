import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WithdrawalScreen extends StatefulWidget {
  const WithdrawalScreen({super.key});

  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  final _upiController = TextEditingController();
  final _amountController = TextEditingController();
  
  bool _isLoading = false;
  int _currentBalance = 0;
  final int _minimumWithdrawal = 1000; // Minimum 1000 coins chahiye

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  // 1. DATABASE SE DATA FETCH KARNA
  Future<void> _fetchUserData() async {
    final user = supabase.auth.currentUser;
    
    // Agar user login nahi hai (Testing mode), toh dummy data dikhayein
    if (user == null) {
      setState(() {
        _currentBalance = 2500; // Dummy balance
        _upiController.text = "testuser@ybl"; // Dummy UPI
      });
      return;
    }

    // Agar user login hai, toh database se asli data layein
    try {
      final response = await supabase
          .from('profiles')
          .select('wallet_balance, upi_id')
          .eq('id', user.id)
          .single();

      setState(() {
        _currentBalance = response['wallet_balance'] ?? 0;
        // Agar pehle se UPI ID save hai, toh use Auto-fill kar do
        if (response['upi_id'] != null) {
          _upiController.text = response['upi_id'];
        }
      });
    } catch (e) {
      print("Error fetching data: $e");
    }
  }

  // 2. WITHDRAWAL LOGIC
  Future<void> _submitWithdrawal() async {
    final user = supabase.auth.currentUser;
    final upiId = _upiController.text.trim();
    final amountText = _amountController.text.trim();

    // Validations
    if (upiId.isEmpty) {
      _showMessage("Please enter a valid UPI ID", isError: true);
      return;
    }
    if (amountText.isEmpty || int.tryParse(amountText) == null) {
      _showMessage("Please enter a valid amount", isError: true);
      return;
    }

    final withdrawAmount = int.parse(amountText);

    if (withdrawAmount < _minimumWithdrawal) {
      _showMessage("Minimum withdrawal is $_minimumWithdrawal coins", isError: true);
      return;
    }
    if (withdrawAmount > _currentBalance) {
      _showMessage("You don't have enough coins", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    // Testing Mode bypass
    if (user == null) {
      await Future.delayed(const Duration(seconds: 2));
      _showMessage("TEST SUCCESS: Withdrawal request sent!");
      setState(() {
        _currentBalance -= withdrawAmount;
        _amountController.clear();
        _isLoading = false;
      });
      return;
    }

    // Asli Database Logic
    try {
      // Step A: Naya table me entry daalo (Withdrawal Request)
      await supabase.from('withdrawals').insert({
        'user_id': user.id,
        'amount': withdrawAmount,
        'upi_id': upiId,
      });

      // Step B: User ka balance kaato aur Naya UPI ID update kar do (agar change kiya ho)
      await supabase.from('profiles').update({
        'wallet_balance': _currentBalance - withdrawAmount,
        'upi_id': upiId, // Ye line UPI ID ko hamesha latest wale se update kar degi
      }).eq('id', user.id);

      // UI Update karein
      setState(() {
        _currentBalance -= withdrawAmount;
        _amountController.clear();
      });

      _showMessage("Withdrawal Request Sent Successfully!");
    } catch (e) {
      _showMessage("Error: ${e.toString()}", isError: true);
    }

    setState(() => _isLoading = false);
  }

  void _showMessage(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==========================================
  // UI SECTION
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF8FD),
      appBar: AppBar(
        title: const Text('Withdraw Funds'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. BALANCE CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))
                ],
              ),
              child: Column(
                children: [
                  const Text("Available Balance", style: TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.amber, size: 35),
                      const SizedBox(width: 10),
                      Text(
                        "$_currentBalance",
                        style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // 2. UPI ID INPUT FIELD
            const Text('Transfer Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF6750A4))),
            const SizedBox(height: 15),
            
            TextField(
              controller: _upiController,
              decoration: InputDecoration(
                labelText: 'UPI ID / Paytm Number',
                hintText: 'e.g. yourname@upi',
                prefixIcon: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF6750A4)),
                // Chota sa text dikhane ke liye ki edit kar sakte hain
                suffixIcon: const Icon(Icons.edit_outlined, color: Colors.grey, size: 20),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF6750A4), width: 2)),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 10, top: 5),
              child: Text("We saved this from your last withdrawal. You can edit it.", style: TextStyle(fontSize: 12, color: Colors.grey)),
            ),

            const SizedBox(height: 25),

            // 3. COINS AMOUNT INPUT FIELD
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Coins to Withdraw',
                hintText: 'Min. $_minimumWithdrawal coins',
                prefixIcon: const Icon(Icons.monetization_on_outlined, color: Color(0xFF6750A4)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF6750A4), width: 2)),
              ),
            ),

            const SizedBox(height: 40),

            // 4. SUBMIT BUTTON
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitWithdrawal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6750A4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 5,
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('SUBMIT REQUEST', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _upiController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}