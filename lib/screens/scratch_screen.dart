import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:scratcher/scratcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'package:unity_ads_plugin/unity_ads_plugin.dart'; 

import '../models/app_settings_model.dart';

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

  int _minReward = 1;
  int _maxReward = 15;
  bool _adsEnabled = true; 
  bool _isAdWatched = false; 

  @override
  void initState() {
    super.initState();
    _initData(); 
  }

  Future<void> _initData() async {
    await _fetchScratchData();
    await _fetchAdminSettings(); 
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
      debugPrint("Error fetching scratch data: $e");
    }
  }

  Future<void> _fetchAdminSettings() async {
    try {
      final response = await Supabase.instance.client
          .from('app_settings')
          .select()
          .single();

      final settings = AppSettingsModel.fromJson(response);

      if (mounted) {
        setState(() {
          _minReward = settings.minScratchReward;
          _maxReward = settings.maxScratchReward;
          _adsEnabled = settings.adsEnabled;
          
          if (!_adsEnabled) {
            _isAdWatched = true; 
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching admin settings. Error: $e");
      if (mounted) {
        setState(() {
          _isAdWatched = true; 
        });
      }
    }
  }

  Future<void> _generateOrLoadReward() async {
    final prefs = await SharedPreferences.getInstance();
    int? savedReward = prefs.getInt('pending_scratch_reward');

    if (savedReward != null) {
      _currentReward = savedReward;
    } else {
      if (_maxReward > _minReward) {
        _currentReward = _minReward + Random().nextInt((_maxReward - _minReward) + 1);
      } else {
        _currentReward = _minReward; 
      }
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
        
        setState(() {
           _scratchesToday++;
           if (_adsEnabled) _isAdWatched = false; 
        }); 
        _startCooldown(); 
      }
    } catch (e) {
      _showSnackBar('Error processing reward.', Colors.red);
    }
  }

  // ==========================================
  // 👇 UPDATE: Smart Ad Loading & Error Handling
  // ==========================================
  void _showUnityVideoAd() {
    _showSnackBar("Loading Ad...", Colors.blue);
    
    // 1. Pehle Ad Load karenge
    UnityAds.load(
      placementId: 'Rewarded_Android',
      onComplete: (placementId) {
        // 2. Load successful hone par Show karenge
        UnityAds.showVideoAd(
          placementId: placementId,
          onStart: (placementId) => debugPrint('Ad Started'),
          onComplete: (placementId) {
            debugPrint('✅ Ad watched fully. Unlock Scratch Card!');
            setState(() {
              _isAdWatched = true; 
            });
          },
          onFailed: (placementId, error, message) {
            debugPrint('❌ Ad Show Failed: $message');
            _showAdErrorDialog(
              "Playback Error", 
              "There was an error playing the video. Please try again."
            );
          },
          onSkipped: (placementId) {
             _showSnackBar('You skipped the ad! Reward not unlocked.', Colors.orange);
          }
        );
      },
      onFailed: (placementId, error, message) {
        debugPrint('❌ Ad Load Failed: $error - $message');
        
        // Agar Load fail hua toh jyadatar reason Adblocker ya slow internet hota hai
        _showAdErrorDialog(
          "Ad Load Failed", 
          "We couldn't load an ad at this moment.\n\n⚠️ Important: If you are using an AdBlocker, Private DNS (like AdGuard), or a VPN, please disable it to earn rewards. Otherwise, check your internet connection."
        );
      },
    );
  }

  // 👇 NAYA: Custom Alert Box for better UX
  void _showAdErrorDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 14, color: Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK, I Understand', style: TextStyle(color: Color(0xFF6750A4), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
                      else if (_adsEnabled && !_isAdWatched && _timerNotifier.value == 0)
                        Container(
                          color: const Color(0xFF6750A4).withOpacity(0.9),
                          child: Center(
                            child: ElevatedButton.icon(
                              onPressed: _showUnityVideoAd,
                              icon: const Icon(Icons.play_circle_fill),
                              label: const Text("Watch Ad to Unlock"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF6750A4),
                              ),
                            ),
                          ),
                        )
                      else ...[
                        Scratcher(
                          key: _scratchKey,
                          brushSize: 45,
                          threshold: 50, 
                          color: const Color(0xFF6750A4),
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
                if (_adsEnabled && !_isAdWatched && timerValue == 0) {
                  return const Text("📺 Watch a short video to play!", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold));
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
