import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'package:unity_ads_plugin/unity_ads_plugin.dart'; 

// 👇 NAYA: Apna model import kiya
import '../models/app_settings_model.dart';

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
  
  // Backend Limits & Data
  final int _dailyLimit = 5; 
  int _spinsToday = 0;
  bool _isLoadingData = true;
  int _winningIndex = 0; 

  // Admin control ke variables
  bool _adsEnabled = true;
  bool _isAdWatched = false;
  
  final List<int> rewards = [2, 5, 8, 10, 12, 15]; 
  
  final List<Color> segmentColors = const [
    Color(0xFFFFD1DC), Color(0xFFFFE5B4), Color(0xFFFFF4CC), 
    Color(0xFFD4F0F0), Color(0xFFE2D5F8), Color(0xFFC1E1C1), 
  ];

  @override
  void initState() {
    super.initState();
    _initData(); 
  }

  Future<void> _initData() async {
    await _fetchSpinData();
    await _fetchAdminSettings(); // 👈 Update kiya hua function
    await _generateOrLoadSpinIndex(); 
    await _checkSavedTimer();
    setState(() => _isLoadingData = false);
  }

  // ==========================================
  // 👇 UPDATE: MODEL KA USE KARKE SETTINGS LAANA
  // ==========================================
  Future<void> _fetchAdminSettings() async {
    try {
      // Data laya gaya
      final response = await Supabase.instance.client
          .from('app_settings')
          .select()
          .single();

      // Model mein convert kiya
      final settings = AppSettingsModel.fromJson(response);

      if (mounted) {
        setState(() {
          // Model se safely value nikali
          _adsEnabled = settings.adsEnabled;
          
          // Agar ads band hain, toh maan lo ad dekh liya taaki spin ho sake
          if (!_adsEnabled) {
            _isAdWatched = true; 
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching admin settings. Error: $e");
      if (mounted) {
        setState(() {
          _isAdWatched = true; // DB Error aaye toh user block na ho
        });
      }
    }
  }

  Future<void> _fetchSpinData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('spins_today, last_activity_date')
          .eq('id', user.id)
          .single();

      final lastDateString = data['last_activity_date']?.toString(); 
      final todayString = DateTime.now().toIso8601String().split('T')[0];

      if (lastDateString != todayString) {
        _spinsToday = 0; 
      } else {
        _spinsToday = data['spins_today'] ?? 0;
      }
    } catch (e) {
      debugPrint("Error fetching spin data: $e");
    }
  }

  Future<void> _generateOrLoadSpinIndex() async {
    final prefs = await SharedPreferences.getInstance();
    int? savedIndex = prefs.getInt('pending_spin_index');

    if (savedIndex != null && savedIndex >= 0 && savedIndex < rewards.length) {
      _winningIndex = savedIndex;
    } else {
      _winningIndex = Fortune.randomInt(0, rewards.length);
      prefs.setInt('pending_spin_index', _winningIndex);
    }
  }

  Future<void> _processRewardInBackend(int amount) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final response = await Supabase.instance.client.rpc(
        'process_spin', 
        params: {'user_uid': user.id, 'win_amount': amount}
      );

      if (response == 'limit_reached') {
        _showSnackBar('Daily limit reached! Come back tomorrow.', Colors.red);
        setState(() => _spinsToday = _dailyLimit); 
      } else if (response == 'success') {
        _showSnackBar('🎉 $amount Coins added to your wallet!', Colors.green);
        
        final prefs = await SharedPreferences.getInstance();
        prefs.remove('pending_spin_index');

        setState(() {
           _spinsToday++;
           // Agle spin ke liye ad fir se dekhna padega (agar ads on hain)
           if (_adsEnabled) _isAdWatched = false; 
        }); 
        _startCooldown(); 
      }
    } catch (e) {
      _showSnackBar('Error processing reward.', Colors.red);
    }
  }

  void _showUnityVideoAd() {
    _showSnackBar("Loading Ad...", Colors.blue);
    
    UnityAds.showVideoAd(
      placementId: 'Rewarded_Android', 
      onStart: (placementId) => debugPrint('Ad Started'),
      onComplete: (placementId) {
        debugPrint('✅ Ad watched fully. Auto-Spinning now!');
        setState(() {
          _isAdWatched = true; 
        });
        _startSpin();
      },
      onFailed: (placementId, error, message) {
        debugPrint('❌ Ad Failed: $message');
        _showSnackBar('Failed to load ad. Please try again later.', Colors.red);
      },
      onSkipped: (placementId) {
         _showSnackBar('You skipped the ad! Spin cancelled.', Colors.orange);
      }
    );
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  void _handleSpinClick() {
    if (_spinsToday >= _dailyLimit) {
      _showSnackBar('You have used all $_dailyLimit spins for today!', Colors.red);
      return;
    }
    if (_timerNotifier.value > 0 || _isSpinning) return; 
    
    if (_adsEnabled && !_isAdWatched) {
      _showUnityVideoAd();
    } else {
      _startSpin();
    }
  }

  void _startSpin() {
    setState(() => _isSpinning = true);
    _selected.add(_winningIndex);
  }

  Future<void> _checkSavedTimer() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSpinTimestamp = prefs.getInt('last_spin_time') ?? 0;

    if (lastSpinTimestamp == 0) return;

    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final diffInSeconds = ((currentTime - lastSpinTimestamp) / 1000).floor();

    if (diffInSeconds < 60) {
      final remainingSeconds = 60 - diffInSeconds;
      _timerNotifier.value = remainingSeconds;
      _startCountdownLogic();
    } else {
      prefs.remove('last_spin_time');
    }
  }

  Future<void> _saveCurrentTime() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('last_spin_time', DateTime.now().millisecondsSinceEpoch);
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
        
        if (_spinsToday < _dailyLimit) {
          _generateOrLoadSpinIndex(); 
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
        title: const Text('Lucky Spin'), 
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
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
                color: _spinsToday >= _dailyLimit ? Colors.red.shade100 : const Color(0xFFEADDFF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "Spins Left: ${_dailyLimit - _spinsToday} / $_dailyLimit",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _spinsToday >= _dailyLimit ? Colors.red : const Color(0xFF6750A4),
                ),
              ),
            ),

            const SizedBox(height: 30),
            
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
                  onAnimationEnd: () async {
                    if (!mounted) return;
                    setState(() => _isSpinning = false);
                    
                    int wonAmount = rewards[_winningIndex];
                    await _processRewardInBackend(wonAmount);
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
                  bool isLimitReached = _spinsToday >= _dailyLimit;
                  
                  String buttonText;
                  if (isLimitReached) {
                    buttonText = "COME BACK TOMORROW";
                  } else if (timerValue > 0) {
                    buttonText = "Wait ${timerValue}s";
                  } else if (_adsEnabled && !_isAdWatched) {
                    buttonText = "WATCH AD TO SPIN";
                  } else {
                    buttonText = "SPIN NOW";
                  }

                  return ElevatedButton.icon(
                    onPressed: (_isSpinning || timerValue > 0 || isLimitReached) ? null : _handleSpinClick,
                    icon: Icon(
                      (_adsEnabled && !_isAdWatched && timerValue == 0 && !isLimitReached) 
                          ? Icons.play_circle_fill 
                          : Icons.casino,
                      color: Colors.white,
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 60),
                      backgroundColor: isLimitReached ? Colors.red.shade400 : const Color(0xFF6750A4),
                      disabledBackgroundColor: Colors.grey.shade400,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      elevation: (timerValue > 0 || isLimitReached) ? 0 : 5, 
                    ),
                    label: Text(
                      buttonText,
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
                if (_spinsToday >= _dailyLimit) {
                  return const Text("🚫 Daily limit reached!", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600));
                }
                if (_adsEnabled && !_isAdWatched && timerValue == 0) {
                  return const Text("📺 Watch a short video to spin!", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold));
                }
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