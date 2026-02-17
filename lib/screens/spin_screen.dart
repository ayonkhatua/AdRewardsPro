import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:shared_preferences/shared_preferences.dart'; // NAYA PACKAGE

class SpinScreen extends StatefulWidget {
  const SpinScreen({super.key});

  @override
  State<SpinScreen> createState() => _SpinScreenState();
}

class _SpinScreenState extends State<SpinScreen> {
  final StreamController<int> _selected = StreamController<int>();
  
  final ValueNotifier<int> _timerNotifier = ValueNotifier<int>(0);
  bool _isSpinning = false;
  Timer? _cooldownTimer;
  
  final List<int> rewards = [5, 10, 20, 50, 100, 200];
  
  final List<Color> segmentColors = const [
    Color(0xFFFFD1DC), Color(0xFFFFE5B4), Color(0xFFFFF4CC), 
    Color(0xFFD4F0F0), Color(0xFFE2D5F8), Color(0xFFC1E1C1), 
  ];

  @override
  void initState() {
    super.initState();
    _checkSavedTimer(); // NAYA: Screen khulte hi purana timer check karega
  }

  // ==========================================
  // NAYA LOGIC: LOCAL STORAGE TIMER
  // ==========================================

  // App khulte hi check karna ki kya 60 second poore hue hain
  Future<void> _checkSavedTimer() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSpinTimestamp = prefs.getInt('last_spin_time') ?? 0;

    if (lastSpinTimestamp == 0) return;

    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final diffInSeconds = ((currentTime - lastSpinTimestamp) / 1000).floor();

    if (diffInSeconds < 60) {
      // Agar 60 second se kam hue hain, toh bacha hua time set karo
      final remainingSeconds = 60 - diffInSeconds;
      _timerNotifier.value = remainingSeconds;
      _startCountdownLogic();
    } else {
      // Agar time nikal gaya toh clear kar do
      prefs.remove('last_spin_time');
    }
  }

  // Spin hote hi current time save karna
  Future<void> _saveCurrentTime() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('last_spin_time', DateTime.now().millisecondsSinceEpoch);
  }

  // ==========================================
  // NORMAL LOGIC SECTION
  // ==========================================

  void _handleSpinClick() {
    if (_timerNotifier.value > 0 || _isSpinning) return; 
    _startSpin();
  }

  void _startSpin() {
    setState(() => _isSpinning = true);
    int winningIndex = Fortune.randomInt(0, rewards.length);
    _selected.add(winningIndex);
  }

  void _startCooldown() {
    _timerNotifier.value = 60; 
    _saveCurrentTime(); // NAYA: Timer start hote hi time save karo
    _startCountdownLogic();
  }

  // Timer chalane ka alag function banaya taaki resume karne me aasaani ho
  void _startCountdownLogic() {
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
  // UI SECTION (Same as before)
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
            
            SizedBox(
              height: 320,
              child: RepaintBoundary(
                child: FortuneWheel(
                  selected: _selected.stream,
                  animateFirst: false,
                  duration: const Duration(seconds: 4), 
                  items: [
                    for (int i = 0; i < rewards.length; i++)
                      FortuneItem(
                        child: Text(
                          rewards[i].toString(), 
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Colors.black87),
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
    _timerNotifier.dispose(); 
    _cooldownTimer?.cancel(); 
    super.dispose();
  }
}