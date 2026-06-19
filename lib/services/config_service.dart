import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 配置管理服务：API Key、应用设置、初始化状态
class ConfigService {
  static const _keyApiKey = 'deepseek_api_key';
  static const _keyIsSetup = 'is_setup_complete';
  static const _keySessionId = 'current_session_id';
  static const _keyMode = 'personality_mode';
  static const _keyExName = 'ex_name';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // ---- API Key ----

  Future<void> setApiKey(String key) async {
    await _secureStorage.write(key: _keyApiKey, value: key);
  }

  Future<String?> getApiKey() async {
    return await _secureStorage.read(key: _keyApiKey);
  }

  // ---- 初始化状态 ----

  Future<bool> isSetupComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsSetup) ?? false;
  }

  Future<void> setSetupComplete(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsSetup, value);
  }

  // ---- 当前会话 ----

  Future<String?> getCurrentSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySessionId);
  }

  Future<void> setCurrentSessionId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySessionId, id);
  }

  // ---- 模式 ----

  Future<String?> getMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyMode);
  }

  Future<void> setMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMode, mode);
  }

  // ---- 前任名字 ----

  Future<String> getExName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyExName) ?? 'TA';
  }

  Future<void> setExName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyExName, name);
  }
}
