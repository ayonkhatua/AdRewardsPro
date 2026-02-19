class AppSettingsModel {
  final int id;
  final String unityGameId;
  final int minScratchReward;
  final int maxScratchReward;
  final bool adsEnabled;
  final String adminEmail;

  AppSettingsModel({
    required this.id,
    required this.unityGameId,
    required this.minScratchReward,
    required this.maxScratchReward,
    required this.adsEnabled,
    required this.adminEmail,
  });

  // 👇 Supabase se aane wale raw data (Map) ko Dart Object mein badalne ke liye
  factory AppSettingsModel.fromJson(Map<String, dynamic> json) {
    return AppSettingsModel(
      id: json['id'] ?? 1,
      unityGameId: json['unity_game_id'] ?? '',
      minScratchReward: json['min_scratch_reward'] ?? 10,
      maxScratchReward: json['max_scratch_reward'] ?? 50,
      adsEnabled: json['ads_enabled'] ?? true,
      adminEmail: json['admin_email'] ?? '',
    );
  }

  // 👇 Dart Object ko wapas Supabase mein save karne layak (Map) banane ke liye
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'unity_game_id': unityGameId,
      'min_scratch_reward': minScratchReward,
      'max_scratch_reward': maxScratchReward,
      'ads_enabled': adsEnabled,
      'admin_email': adminEmail,
    };
  }
}