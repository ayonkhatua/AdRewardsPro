import 'dart:async';
import 'package:flutter/material.dart';
// import 'package:unity_ads_plugin/unity_ads_plugin.dart'; // TODO: Uncomment later
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';

class SpinScreen extends StatefulWidget {
  const SpinScreen({super.key});

  @override
  State<SpinScreen> createState() => _SpinScreenState();
}

class _SpinScreenState extends State<SpinScreen> {
  final StreamController<int> _selected = StreamController<int>();
  
  // Optimization 2: ValueNotifier for Timer (Prevents full screen rebuilds)
  final ValueNotifier<int> _timerNotifier = ValueNotifier<int>(0);
  bool _isSpinning = false;
  Timer? _cooldownTimer;
  
  // Rewards list
  final List<int> rewards = [5, 10, 20, 50, 100, 200];
  
  // Modern pastel colors for the wheel segments
  final List<Color> segmentColors = const [
    Color(0xFFFFD1DC), // Pink
    Color(0xFFFFE5B4), // Peach
    Color(0xFFFFF4CC), // Yellow
    Color(0xFFD4F0F0), // Mint
    Color(0xFFE2D5F8), // Lavender
    Color(0xFFC1E1C1), // Green
  ];

  @override
  void initState() {
    super.initState();
    // _initUnityAds(); 
  }

  // ==========================================
  // LOGIC SECTION
  // ==========================================

  void _handleSpinClick() {
    if (_timerNotifier.value > 0 || _isSpinning) return; 

    // TESTING MODE: Seedha spin start karo (Bina ad ke)
    _startSpin();
  }

  void _startSpin() {
    setState(() => _isSpinning = true);
    // Randomly select a winning index
    int winningIndex = Fortune.randomInt(0, rewards.length);
    _selected.add(winningIndex);
  }

  void _startCooldown() {
    _timerNotifier.value = 60; // 60 seconds cooldown
    
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_timerNotifier.value <= 1) {
        timer.cancel();
        _timerNotifier.value = 0;
      } else {
        _timerNotifier.value--;
      }
    });
  }

  // ==========================================
  // UI SECTION
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF8FD), 
      appBar: AppBar(
        title: const Text('Lucky Spin'), 
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            
            // 1. MODERN SPIN WHEEL (Optimized)
            SizedBox(
              height: 320,
              // Optimization 1: RepaintBoundary stops the widget from redrawing every frame
              child: RepaintBoundary(
                child: FortuneWheel(
                  selected: _selected.stream,
                  animateFirst: false,
                  // Directly set duration here for smooth programmatic spins
                  duration: const Duration(seconds: 4), 
                  items: [
                    for (int i = 0; i < rewards.length; i++)
                      FortuneItem(
                        child: Text(
                          rewards[i].toString(), 
                          style: const TextStyle(
                            fontWeight: FontWeight.w900, 
                            fontSize: 24,
                            color: Colors.black87,
                          ),
                        ),
                        style: FortuneItemStyle(
                          color: segmentColors[i % segmentColors.length], 
                          borderColor: Colors.white,
                          borderWidth: 4,
                        ),
                      ),
                  ],
                  onAnimationEnd: () {
                    if (!mounted) return;
                    setState(() => _isSpinning = false);
                    _startCooldown();
                    
                    // TODO: Yahan backend me coins add karne ka logic aayega
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🎉 Coins added to your wallet!'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                ),
              ),
            ),
            
            const SizedBox(height: 50),

            // 2. SPIN BUTTON WITH TIMER
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: ValueListenableBuilder<int>(
                valueListenable: _timerNotifier,
                builder: (context, timerValue, child) {
                  return ElevatedButton(
                    onPressed: (_isSpinning || timerValue > 0) ? null : _handleSpinClick,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 60),
                      backgroundColor: const Color(0xFF6750A4),
                      disabledBackgroundColor: Colors.grey.shade400,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      elevation: timerValue > 0 ? 0 : 5, 
                    ),
                    child: Text(
                      timerValue > 0 ? "Wait ${timerValue}s" : "SPIN NOW",
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),
            
            // 3. STATUS TEXT
            ValueListenableBuilder<int>(
              valueListenable: _timerNotifier,
              builder: (context, timerValue, child) {
                return Text(
                  timerValue > 0 ? "⏳ Take a breath! Next spin soon." : "✨ Ready to win big?",
                  style: TextStyle(
                    color: timerValue > 0 ? Colors.grey.shade600 : const Color(0xFF6750A4), 
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _selected.close();
    _timerNotifier.dispose(); // Memory clear
    _cooldownTimer?.cancel(); 
    super.dispose();
  }
}