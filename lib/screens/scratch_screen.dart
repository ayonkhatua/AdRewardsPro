import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:scratcher/scratcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 

class ScratchScreen extends StatefulWidget {
  const ScratchScreen({super.key});

  @override
  State<ScratchScreen> createState() => _ScratchScreenState();
}

class _ScratchScreenState extends State<ScratchScreen> {
  final GlobalKey<ScratcherState> _scratchKey = GlobalKey<ScratcherState>();
  
  final ValueNotifier<int> _timerNotifier = ValueNotifier<int>(0);
  Timer? _cooldownTimer;
  
  final int _dailyLimit = 3; 
  int _scratchesToday = 0;
  bool _isLoadingData = true;
  int _currentReward = 0;
  bool _isRevealed = false;

  @override
  void initState() {
    super.initState();
    _initData(); 
  }

  Future<void> _initData() async {
    await _fetchScratchData();
    await _generateOrLoadReward();
    await _checkSavedTimer();
    setState(() => _isLoadingData = false);
  }

  Future<void> _fetchScratchData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('scratches_today, last_activity_date')
          .eq('id', user.id)
          .single();

      final lastDateString = data['last_activity_date'];
      final todayString = DateTime.now().toIso8601String().split('T')[0];

      if (lastDateString != todayString) {
        _scratchesToday = 0; 
      } else {
        _scratchesToday = data['scratches_today'] ?? 0;
      }
    } catch (e) {
      print("Error fetching scratch data: $e");
    }
  }

  Future<void> _generateOrLoadReward() async {
    final prefs = await SharedPreferences.getInstance();
    int? savedReward = prefs.getInt('pending_scratch_reward');

    if (savedReward != null) {
      _currentReward = savedReward;
    } else {
      // NAYA: Random coin ab 1 se lekar 15 ke beech milega
      _currentReward = Random().nextInt(15) + 1; 
      prefs.setInt('pending_scratch_reward', _currentReward);
    }
    _isRevealed = false;
  }

  Future<void> _processRewardInBackend() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final response = await Supabase.instance.client.rpc(
        'process_scratch', 
        params: {'user_uid': user.id, 'win_amount': _currentReward}
      );

      if (response == 'limit_reached') {
        _showSnackBar('Daily limit reached! Come back tomorrow.', Colors.red);
        setState(() => _scratchesToday = _dailyLimit); 
      } else if (response == 'success') {
        _showSnackBar('🎉 $_currentReward Coins added to your wallet!', Colors.green);
        
        final prefs = await SharedPreferences.getInstance();
        prefs.remove('pending_scratch_reward');
        
        setState(() => _scratchesToday++); 
        _startCooldown(); 
      }
    } catch (e) {
      _showSnackBar('Error processing reward.', Colors.red);
    }
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  void _handleScratchComplete() {
    if (_isRevealed) return; 
    setState(() => _isRevealed = true);
    _processRewardInBackend();
  }

  Future<void> _checkSavedTimer() async {
    final prefs = await SharedPreferences.getInstance();
    final lastScratchTimestamp = prefs.getInt('last_scratch_time') ?? 0;

    if (lastScratchTimestamp == 0) return;

    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final diffInSeconds = ((currentTime - lastScratchTimestamp) / 1000).floor();

    if (diffInSeconds < 60) {
      final remainingSeconds = 60 - diffInSeconds;
      _timerNotifier.value = remainingSeconds;
      _isRevealed = true; 
      _startCountdownLogic();
    } else {
      prefs.remove('last_scratch_time');
    }
  }

  Future<void> _saveCurrentTime() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('last_scratch_time', DateTime.now().millisecondsSinceEpoch);
  }

  void _startCooldown() {
    _timerNotifier.value = 60; 
    _saveCurrentTime(); 
    _startCountdownLogic();
  }

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
        
        if (_scratchesToday < _dailyLimit) {
          _scratchKey.currentState?.reset(duration: const Duration(milliseconds: 500));
          _generateOrLoadReward(); 
        }
      } else {
        _timerNotifier.value--;
      }
    });
  }

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
      body: _isLoadingData
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF6750A4)))
        : SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _scratchesToday >= _dailyLimit ? Colors.red.shade100 : const Color(0xFFEADDFF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "Scratches Left: ${_dailyLimit - _scratchesToday} / $_dailyLimit",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _scratchesToday >= _dailyLimit ? Colors.red : const Color(0xFF6750A4),
                ),
              ),
            ),

            const SizedBox(height: 40),

            Center(
              child: Container(
                width: 300,
                height: 220,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4CC), 
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFDE293), width: 3),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, spreadRadius: 2)]
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: Stack(
                    children: [
                      if (_scratchesToday >= _dailyLimit)
                        _buildOverlayMessage("DAILY LIMIT REACHED", Colors.red.shade100, Colors.red)
                      else ...[
                        Scratcher(
                          key: _scratchKey,
                          brushSize: 45,
                          threshold: 50, 
                          color: const Color(0xFF6750A4),
                          // Image hata di taaki loading issue na ho. Color fast load hota hai.
                          onThreshold: _handleScratchComplete,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text("+$_currentReward", style: const TextStyle(fontSize: 60, fontWeight: FontWeight.w900, color: Color(0xFF146C2E))),
                                const Text("COINS WON", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                        
                        ValueListenableBuilder<int>(
                          valueListenable: _timerNotifier,
                          builder: (context, timerValue, child) {
                            if (timerValue > 0) {
                              return _buildOverlayMessage("Wait for ${timerValue}s", Colors.black54, Colors.white);
                            }
                            return const SizedBox.shrink(); 
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
            
            ValueListenableBuilder<int>(
              valueListenable: _timerNotifier,
              builder: (context, timerValue, child) {
                if (_scratchesToday >= _dailyLimit) {
                  return const Text("🚫 Come back tomorrow!", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold));
                }
                return Text(
                  timerValue > 0 ? "⏳ Preparing next card..." : "✨ Swipe to reveal your prize!",
                  style: const TextStyle(color: Color(0xFF6750A4), fontWeight: FontWeight.bold),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlayMessage(String message, Color bgColor, Color textColor) {
    return Container(
      color: bgColor,
      child: Center(
        child: Text(message, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textColor)),
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