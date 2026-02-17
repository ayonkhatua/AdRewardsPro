import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WithdrawalScreen extends StatefulWidget {
  const WithdrawalScreen({super.key});

  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _upiController = TextEditingController();
  
  int _walletBalance = 0;
  int _requiredCoins = 0;
  bool _isLoading = false;
  
  // Withdrawal settings
  final int _minimumRupeeWithdrawal = 10; // Minimum ₹10 nikal sakte hain

  @override
  void initState() {
    super.initState();
    _fetchWalletBalance();
    
    // Jaise hi user Rupee type karega, Coins automatically calculate honge
    _amountController.addListener(_calculateCoins);
  }

  Future<void> _fetchWalletBalance() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      // Testing Mode
      setState(() => _walletBalance = 5000); 
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('wallet_balance')
          .eq('id', user.id)
          .single();

      setState(() {
        _walletBalance = response['wallet_balance'] ?? 0;
      });
    } catch (e) {
      print("Error: $e");
    }
  }

  void _calculateCoins() {
    final rupeeAmount = int.tryParse(_amountController.text) ?? 0;
    setState(() {
      // Math: ₹1 = 50 Coins (Kyunki ₹2 = 100 Coins)
      _requiredCoins = rupeeAmount * 50; 
    });
  }

  Future<void> _submitWithdrawal() async {
    final rupeeAmount = int.tryParse(_amountController.text) ?? 0;
    final upiId = _upiController.text.trim();

    if (rupeeAmount < _minimumRupeeWithdrawal) {
      _showSnackBar('Minimum withdrawal is ₹$_minimumRupeeWithdrawal', Colors.red);
      return;
    }

    if (_requiredCoins > _walletBalance) {
      _showSnackBar('Not enough coins! You need $_requiredCoins coins.', Colors.red);
      return;
    }

    if (upiId.isEmpty || !upiId.contains('@')) {
      _showSnackBar('Please enter a valid UPI ID.', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      
      if (user != null) {
        // 1. Withdrawals table me request daalo (Admin ke liye asaan, amount ₹ me jayega)
        await Supabase.instance.client.from('withdrawals').insert({
          'user_id': user.id,
          'amount_in_rupees': rupeeAmount,
          'coins_deducted': _requiredCoins,
          'upi_id': upiId,
          'status': 'pending',
        });

        // 2. User ke wallet se turant coins kaat lo
        final newBalance = _walletBalance - _requiredCoins;
        await Supabase.instance.client
            .from('profiles')
            .update({'wallet_balance': newBalance})
            .eq('id', user.id);
            
        setState(() => _walletBalance = newBalance);
      }

      _showSnackBar('Withdrawal request sent successfully!', Colors.green);
      _amountController.clear();
      _upiController.clear();
      
      // Request successful hone par thodi der baad back kar do
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });

    } catch (e) {
      _showSnackBar('Error processing request. Try again.', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. WALLET BALANCE CARD
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6750A4), Color(0xFF9A82DB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: const Color(0xFF6750A4).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
                ),
                child: Column(
                  children: [
                    const Text("Available Coins", style: TextStyle(color: Colors.white70, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(
                      "$_walletBalance", 
                      style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // 2. RUPEE INPUT SECTION
              const Text("Enter Amount (in ₹)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1D1B20))),
              const SizedBox(height: 10),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF6750A4)),
                decoration: InputDecoration(
                  prefixText: "₹ ",
                  prefixStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF6750A4)),
                  filled: true,
                  fillColor: Colors.white,
                  hintText: "e.g. 50",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF6750A4), width: 2)),
                ),
              ),

              const SizedBox(height: 12),

              // DYNAMIC COIN CALCULATION TEXT
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    _requiredCoins > 0 
                      ? "$_requiredCoins Coins will be deducted." 
                      : "100 Coins = ₹2 (Min. ₹$_minimumRupeeWithdrawal)",
                    style: TextStyle(
                      color: (_requiredCoins > _walletBalance) ? Colors.red : Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // 3. UPI INPUT SECTION
              const Text("UPI ID / Number", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1D1B20))),
              const SizedBox(height: 10),
              TextField(
                controller: _upiController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.account_balance_rounded, color: Color(0xFF6750A4)),
                  filled: true,
                  fillColor: Colors.white,
                  hintText: "e.g. enter your upi id or number",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF6750A4), width: 2)),
                ),
              ),

              const SizedBox(height: 40),

              // 4. SUBMIT BUTTON
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitWithdrawal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6750A4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 5,
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("WITHDRAW NOW", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _upiController.dispose();
    super.dispose();
  }
}