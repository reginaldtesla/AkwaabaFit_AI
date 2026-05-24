import 'package:shared_preferences/shared_preferences.dart';

/// User has opened the app at least once and step tracking was configured.
abstract final class PersistentStepTrackingPrefs {
  static const _configuredKey = 'akwaaba_step_tracking_configured';
  static const _batteryPromptedKey = 'akwaaba_battery_opt_prompted';

  static Future<bool> isConfigured() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_configuredKey) ?? false;
  }

  static Future<void> markConfigured() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_configuredKey, true);
  }

  static Future<bool> wasBatteryOptimizationPrompted() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_batteryPromptedKey) ?? false;
  }

  static Future<void> markBatteryOptimizationPrompted() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_batteryPromptedKey, true);
  }
}
