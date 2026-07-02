// lib/core/services/storage_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Keys
  static const _tokenKey = 'auth_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _driverIdKey = 'driver_id';

  // Hive box for non-sensitive prefs
  Box? _prefsBox;

  Future<void> init() async {
    await Hive.initFlutter();
    _prefsBox = await Hive.openBox('prefs');
  }

  // --- Secure (JWT) ---

  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return _secureStorage.read(key: _tokenKey);
  }

  Future<void> saveRefreshToken(String token) async {
    await _secureStorage.write(key: _refreshTokenKey, value: token);
  }

  Future<String?> getRefreshToken() async {
    return _secureStorage.read(key: _refreshTokenKey);
  }

  Future<void> saveDriverId(int id) async {
    await _secureStorage.write(key: _driverIdKey, value: id.toString());
  }

  Future<int?> getDriverId() async {
    final val = await _secureStorage.read(key: _driverIdKey);
    return val != null ? int.tryParse(val) : null;
  }

  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
    await _prefsBox?.clear();
  }

  // --- Hive prefs (non-sensitive) ---

  Future<void> setBool(String key, bool value) async {
    await _prefsBox?.put(key, value);
  }

  bool getBool(String key, {bool defaultValue = false}) {
    return _prefsBox?.get(key, defaultValue: defaultValue) ?? defaultValue;
  }

  Future<void> setString(String key, String value) async {
    await _prefsBox?.put(key, value);
  }

  String? getString(String key) {
    return _prefsBox?.get(key);
  }
}
