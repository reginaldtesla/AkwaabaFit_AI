class AppUpdateInfo {
  const AppUpdateInfo({
    required this.latestVersion,
    required this.storeUrl,
    required this.message,
    required this.updateAvailable,
    required this.forceUpdate,
    required this.showBanner,
  });

  final String latestVersion;
  final String storeUrl;
  final String message;
  final bool updateAvailable;
  final bool forceUpdate;

  /// False when user dismissed this latest version or no update needed.
  final bool showBanner;
}
