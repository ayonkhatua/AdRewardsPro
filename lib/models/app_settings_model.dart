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
  
  // 👇 EK AUR NAYA FIELD: Tab Switch Ad Interval ke liye
  final int interAdInterval;

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
    // 👇 CONSTRUCTOR MEIN ADD KIYA
    required this.interAdInterval,
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
      // 👇 JSON SE NIKALNE KE LIYE (Default 5 set kiya hai)
      interAdInterval: json['inter_ad_interval'] ?? 5,
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
      // 👇 WAPAS JSON BANANE KE LIYE
      'inter_ad_interval': interAdInterval,
    };
  }
}