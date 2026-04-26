import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const String _keyDeviceName = 'device_name';
  static const String _keyAutoStartNetwork = 'auto_start_network';
  static const String _keyEncryptionEnabled = 'encryption_enabled';
  static const String _keyMaxHops = 'max_hops';
  static const String _keyDiscoveryInterval = 'discovery_interval';
  static const String _keyLogLevel = 'log_level';
  static const String _keyBackgroundService = 'background_service';
  static const String _keyBatteryOptimization = 'battery_optimization';
  static const String _keyFirstLaunch = 'first_launch';

  Future<SharedPreferences> get _prefs async => await SharedPreferences.getInstance();

  // Device Settings
  Future<String> getDeviceName() async {
    final prefs = await _prefs;
    return prefs.getString(_keyDeviceName) ?? 'FileManager';
  }

  Future<void> setDeviceName(String name) async {
    final prefs = await _prefs;
    await prefs.setString(_keyDeviceName, name);
  }

  // Network Settings
  Future<bool> getAutoStartNetwork() async {
    final prefs = await _prefs;
    return prefs.getBool(_keyAutoStartNetwork) ?? false;
  }

  Future<void> setAutoStartNetwork(bool enabled) async {
    final prefs = await _prefs;
    await prefs.setBool(_keyAutoStartNetwork, enabled);
  }

  Future<bool> getEncryptionEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(_keyEncryptionEnabled) ?? true;
  }

  Future<void> setEncryptionEnabled(bool enabled) async {
    final prefs = await _prefs;
    await prefs.setBool(_keyEncryptionEnabled, enabled);
  }

  Future<int> getMaxHops() async {
    final prefs = await _prefs;
    return prefs.getInt(_keyMaxHops) ?? 3;
  }

  Future<void> setMaxHops(int hops) async {
    final prefs = await _prefs;
    await prefs.setInt(_keyMaxHops, hops.clamp(1, 10));
  }

  Future<int> getDiscoveryInterval() async {
    final prefs = await _prefs;
    return prefs.getInt(_keyDiscoveryInterval) ?? 30; // seconds
  }

  Future<void> setDiscoveryInterval(int seconds) async {
    final prefs = await _prefs;
    await prefs.setInt(_keyDiscoveryInterval, seconds.clamp(10, 300));
  }

  // System Settings
  Future<String> getLogLevel() async {
    final prefs = await _prefs;
    return prefs.getString(_keyLogLevel) ?? 'INFO';
  }

  Future<void> setLogLevel(String level) async {
    final prefs = await _prefs;
    final validLevels = ['DEBUG', 'INFO', 'WARNING', 'ERROR'];
    final normalizedLevel = level.toUpperCase();
    if (validLevels.contains(normalizedLevel)) {
      await prefs.setString(_keyLogLevel, normalizedLevel);
    }
  }

  Future<bool> getBackgroundServiceEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(_keyBackgroundService) ?? true;
  }

  Future<void> setBackgroundServiceEnabled(bool enabled) async {
    final prefs = await _prefs;
    await prefs.setBool(_keyBackgroundService, enabled);
  }

  Future<bool> getBatteryOptimizationDisabled() async {
    final prefs = await _prefs;
    return prefs.getBool(_keyBatteryOptimization) ?? false;
  }

  Future<void> setBatteryOptimizationDisabled(bool disabled) async {
    final prefs = await _prefs;
    await prefs.setBool(_keyBatteryOptimization, disabled);
  }

  // App State
  Future<bool> isFirstLaunch() async {
    final prefs = await _prefs;
    return prefs.getBool(_keyFirstLaunch) ?? true;
  }

  Future<void> setFirstLaunchComplete() async {
    final prefs = await _prefs;
    await prefs.setBool(_keyFirstLaunch, false);
  }

  // Utility Methods
  Future<void> resetToDefaults() async {
    final prefs = await _prefs;
    await prefs.clear();
  }

  Future<Map<String, dynamic>> getAllSettings() async {
    final prefs = await _prefs;
    return {
      'deviceName': prefs.getString(_keyDeviceName) ?? 'FileManager',
      'autoStartNetwork': prefs.getBool(_keyAutoStartNetwork) ?? false,
      'encryptionEnabled': prefs.getBool(_keyEncryptionEnabled) ?? true,
      'maxHops': prefs.getInt(_keyMaxHops) ?? 3,
      'discoveryInterval': prefs.getInt(_keyDiscoveryInterval) ?? 30,
      'logLevel': prefs.getString(_keyLogLevel) ?? 'INFO',
      'backgroundService': prefs.getBool(_keyBackgroundService) ?? true,
      'batteryOptimization': prefs.getBool(_keyBatteryOptimization) ?? false,
    };
  }

  Future<void> exportSettings() async {
    final settings = await getAllSettings();
    // This could be implemented to export to a file
    print('Settings exported: $settings');
  }

  Future<void> importSettings(Map<String, dynamic> settings) async {
    final prefs = await _prefs;
    
    if (settings.containsKey('deviceName')) {
      await prefs.setString(_keyDeviceName, settings['deviceName']);
    }
    if (settings.containsKey('autoStartNetwork')) {
      await prefs.setBool(_keyAutoStartNetwork, settings['autoStartNetwork']);
    }
    if (settings.containsKey('encryptionEnabled')) {
      await prefs.setBool(_keyEncryptionEnabled, settings['encryptionEnabled']);
    }
    if (settings.containsKey('maxHops')) {
      await prefs.setInt(_keyMaxHops, settings['maxHops']);
    }
    if (settings.containsKey('discoveryInterval')) {
      await prefs.setInt(_keyDiscoveryInterval, settings['discoveryInterval']);
    }
    if (settings.containsKey('logLevel')) {
      await prefs.setString(_keyLogLevel, settings['logLevel']);
    }
    if (settings.containsKey('backgroundService')) {
      await prefs.setBool(_keyBackgroundService, settings['backgroundService']);
    }
    if (settings.containsKey('batteryOptimization')) {
      await prefs.setBool(_keyBatteryOptimization, settings['batteryOptimization']);
    }
  }
}
