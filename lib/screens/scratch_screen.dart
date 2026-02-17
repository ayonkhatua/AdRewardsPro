import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:scratcher/scratcher.dart';
// import 'package:unity_ads_plugin/unity_ads_plugin.dart'; // TODO: Ads System (Blocked for testing)

class ScratchScreen extends StatefulWidget {
  const ScratchScreen({super.key});

  @override
  State<ScratchScreen> createState() => _ScratchScreenState();
}

class _ScratchScreenState extends State<ScratchScreen> {
  final GlobalKey<ScratcherState> _scratchKey = GlobalKey<ScratcherState>();
  
  // Optimization 1: ValueNotifier use kiya hai taaki poori screen rebuild na ho
  final ValueNotifier<int> _timerNotifier = ValueNotifier<int>(0);
  Timer? _cooldownTimer;
  
  final int _dailyLimit = 3; 
  int _scratchCount = 0; 
  int _currentReward = 0;
  bool _isRevealed = false;

  @override
  void initState() {
    super.initState();
    _generateReward();
  }

  // ==========================================
  // LOGIC SECTION
  // ==========================================

  void _generateReward() {
    // 1 se 10 ke beech random points
    _currentReward = Random().nextInt(10) + 1;
    _isRevealed = false;
  }

  void _handleScratchComplete() {
    if (_isRevealed) return; // Double trigger rokne ke liye
    
    setState(() {
      _isRevealed = true;
      _scratchCount++;
    });

    // TODO: Yahan backend (Supabase) me coins update karne ka logic aayega

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎉 You won $_currentReward coins!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );

    _startCooldown();
  }

  void _startCooldown() {
    _timerNotifier.value = 60; // 60 Seconds Timer Setup
    
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      if (_timerNotifier.value <= 1) {
        timer.cancel();
        _timerNotifier.value = 0;
        
        // Optimization 2: Timer khatam hone par card Auto-Reset hoga (Agar limit bachi hai)
        if (_scratchCount < _dailyLimit) {
          _scratchKey.currentState?.reset(duration: const Duration(milliseconds: 500));
          _generateReward();
        }
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
        title: const Text('Scratch & Win'), 
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 30),
            
            // BALANCE DISPLAY
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Try your luck!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFEADDFF), width: 2),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.monetization_on, color: Color(0xFF6750A4), size: 20),
                        SizedBox(width: 5),
                        Text("Wallet", style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 40),

            // MODERN SCRATCH CARD AREA
            Center(
              child: Container(
                width: 300,
                height: 220,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4CC), 
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFDE293), width: 3),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, spreadRadius: 2)
                  ]
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: Stack(
                    children: [
                      // Optimization 3: Strict Limit & Timer Overlay Logic
                      if (_scratchCount >= _dailyLimit)
                        _buildOverlayMessage("DAILY LIMIT REACHED", Colors.red.shade100, Colors.red)
                      else ...[
                        Scratcher(
                          key: _scratchKey,
                          brushSize: 45,
                          threshold: 50, // 50% scratch par reward open hoga
                          color: const Color(0xFF6750A4),
                          image: Image.network(
                            "https://img.freepik.com/free-vector/abstract-purple-gradient-background_23-2148281137.jpg",
                            fit: BoxFit.cover,
                          ),
                          onThreshold: _handleScratchComplete,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "+$_currentReward",
                                  style: const TextStyle(fontSize: 60, fontWeight: FontWeight.w900, color: Color(0xFF146C2E)),
                                ),
                                const Text("COINS WON", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                        
                        // Smart Timer Overlay (ValueListenableBuilder for performance)
                        ValueListenableBuilder<int>(
                          valueListenable: _timerNotifier,
                          builder: (context, timerValue, child) {
                            if (timerValue > 0) {
                              return _buildOverlayMessage("Wait for ${timerValue}s", Colors.black54, Colors.white);
                            }
                            return const SizedBox.shrink(); // Hide overlay if timer is 0
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
            
            // INSTRUCTION TEXT
            ValueListenableBuilder<int>(
              valueListenable: _timerNotifier,
              builder: (context, timerValue, child) {
                if (_scratchCount >= _dailyLimit) {
                  return const Text("Come back tomorrow!", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold));
                }
                return Text(
                  timerValue > 0 ? "⏳ Preparing next card..." : "✨ Swipe to reveal your prize!",
                  style: const TextStyle(color: Color(0xFF6750A4), fontWeight: FontWeight.bold),
                );
              },
            ),

            const SizedBox(height: 40),

            // LIMIT TEXT
            Text(
              "Daily limits: $_scratchCount / $_dailyLimit",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF6750A4)),
            ),
          ],
        ),
      ),
    );
  }

  // Overlay UI builder function
  Widget _buildOverlayMessage(String message, Color bgColor, Color textColor) {
    return Container(
      color: bgColor,
      child: Center(
        child: Text(
          message, 
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textColor),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _timerNotifier.dispose();
    super.dispose();
  }
}