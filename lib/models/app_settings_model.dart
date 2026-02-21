class AppSettingsModel {
  final int id;
  final String unityGameId;
  final int minScratchReward;
  final int maxScratchReward;
  final bool adsEnabled;
  final String adminEmail;
  
  final bool isTestMode;
  final bool isMaintenance;
  final int appVersion;
  final String updateUrl;
  final String updateMessage;
  
  // Tab Switch Ad Interval ke liye
  final int interAdInterval;

  // 👇 NAYE FIELDS: Economy aur Referral System ke liye
  final int minWithdrawalLimit;
  final int referralBonusAmount;
  final int joiningBonusAmount;

  AppSettingsModel({
    required this.id,
    required this.unityGameId,
    required this.minScratchReward,
    required this.maxScratchReward,
    required this.adsEnabled,
    required this.adminEmail,
    required this.isTestMode,
    required this.isMaintenance,
    required this.appVersion,
    required this.updateUrl,
    required this.updateMessage,
    required this.interAdInterval,
    // 👇 CONSTRUCTOR MEIN ADD KIYE
    required this.minWithdrawalLimit,
    required this.referralBonusAmount,
    required this.joiningBonusAmount,
  });

  factory AppSettingsModel.fromJson(Map<String, dynamic> json) {
    return AppSettingsModel(
      id: json['id'] ?? 1,
      unityGameId: json['unity_game_id'] ?? '',
      minScratchReward: json['min_scratch_reward'] ?? 10,
      maxScratchReward: json['max_scratch_reward'] ?? 50,
      adsEnabled: json['ads_enabled'] ?? true,
      adminEmail: json['admin_email'] ?? '',
      isTestMode: json['is_test_mode'] ?? true, 
      isMaintenance: json['is_maintenance'] ?? false,
      appVersion: json['app_version'] ?? 1,
      updateUrl: json['update_url'] ?? '',
      updateMessage: json['update_message'] ?? 'A new update is available. Please update the app to continue earning.',
      interAdInterval: json['inter_ad_interval'] ?? 5,
      // 👇 JSON SE NIKALNE KE LIYE (Defaults set kiye hain)
      minWithdrawalLimit: json['min_withdrawal_limit'] ?? 500,
      referralBonusAmount: json['referral_bonus_amount'] ?? 100,
      joiningBonusAmount: json['joining_bonus_amount'] ?? 50,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'unity_game_id': unityGameId,
      'min_scratch_reward': minScratchReward,
      'max_scratch_reward': maxScratchReward,
      'ads_enabled': adsEnabled,
      'admin_email': adminEmail,
      'is_test_mode': isTestMode,
      'is_maintenance': isMaintenance,
      'app_version': appVersion,
      'update_url': updateUrl,
      'update_message': updateMessage,
      'inter_ad_interval': interAdInterval,
      // 👇 WAPAS JSON BANANE KE LIYE
      'min_withdrawal_limit': minWithdrawalLimit,
      'referral_bonus_amount': referralBonusAmount,
      'joining_bonus_amount': joiningBonusAmount,
    };
  }
}