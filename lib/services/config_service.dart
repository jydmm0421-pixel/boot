import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 配置管理服务：API Key、应用设置、初始化状态
class ConfigService {
  static const _keyApiKey = 'deepseek_api_key';
  static const _keyIsSetup = 'is_setup_complete';
  static const _keySessionId = 'current_session_id';
  static const _keyMode = 'personality_mode';
  static const _keyExName = 'ex_name';
  static const _keyExGender = 'ex_gender';
  static const _keyImageGenKey = 'image_gen_api_key';
  static const _keyImageGenModel = 'image_gen_model';
  static const _keyUserAvatar = 'user_avatar_base64';
  static const _keyBotAvatar = 'bot_avatar_base64';

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

  // ---- 机器人性别 ----

  Future<String> getExGender() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyExGender) ?? 'female';
  }

  Future<void> setExGender(String gender) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyExGender, gender);
  }

  // ---- 生图 API Key ----

  Future<String?> getImageGenApiKey() async {
    return await _secureStorage.read(key: _keyImageGenKey);
  }

  Future<void> setImageGenApiKey(String key) async {
    await _secureStorage.write(key: _keyImageGenKey, value: key);
  }

  Future<String?> getImageGenModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyImageGenModel);
  }

  Future<void> setImageGenModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyImageGenModel, model);
  }

  // ---- 头像（base64，存在 SharedPreferences） ----

  Future<String?> getUserAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserAvatar);
  }

  Future<void> setUserAvatar(String base64) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserAvatar, base64);
  }

  Future<String?> getBotAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyBotAvatar);
  }

  Future<void> setBotAvatar(String base64) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBotAvatar, base64);
  }
}
