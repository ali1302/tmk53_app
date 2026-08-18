class AppUpdateInfo {
  const AppUpdateInfo({
    required this.platform,
    required this.latestVersion,
    required this.minVersion,
    required this.storeUrl,
    required this.updateMessage,
  });

  final String platform;
  final String latestVersion;
  final String minVersion;
  final String storeUrl;
  final String updateMessage;

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      platform: '${json['platform'] ?? ''}'.trim(),
      latestVersion: '${json['latest_version'] ?? ''}'.trim(),
      minVersion: '${json['min_version'] ?? ''}'.trim(),
      storeUrl: '${json['store_url'] ?? ''}'.trim(),
      updateMessage: '${json['update_message'] ?? ''}'.trim(),
    );
  }
}

enum AppUpdatePrompt { none, optional, required }
