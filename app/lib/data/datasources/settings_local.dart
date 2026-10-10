import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/error/exceptions.dart';

/// Settings on this device: the hub URL and theme in shared preferences,
/// the token in the platform keystore.
class SettingsLocalDataSource {
  SettingsLocalDataSource({FlutterSecureStorage? secure, Map<String, String>? environment})
      : _secure = secure ?? const FlutterSecureStorage(),
        _env = environment ?? Platform.environment;

  static const _urlKey = 'hub_url';
  static const _tokenKey = 'hub_token';
  static const _themeKey = 'theme_mode';

  final FlutterSecureStorage _secure;
  final Map<String, String> _env;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<(String url, String token)> readConnection() async {
    try {
      final prefs = await _prefs;
      var url = prefs.getString(_urlKey) ?? '';
      var token = '';
      try {
        token = await _secure.read(key: _tokenKey) ?? '';
      } on Exception {
        // A keystore wiped by reinstalling the app can't be read; ask again.
      }
      // Desktop convenience: the same variables tetherctl uses.
      if (url.isEmpty) url = _env['TETHER_HUB'] ?? '';
      if (token.isEmpty) token = _env['TETHER_TOKEN'] ?? '';
      return (url, token);
    } on Exception catch (e) {
      throw StorageException(e.toString());
    }
  }

  Future<void> writeConnection(String url, String token) async {
    try {
      await (await _prefs).setString(_urlKey, url);
      await _secure.write(key: _tokenKey, value: token);
    } on Exception catch (e) {
      throw StorageException(e.toString());
    }
  }

  Future<String?> readTheme() async {
    try {
      return (await _prefs).getString(_themeKey);
    } on Exception {
      return null;
    }
  }

  Future<void> writeTheme(String name) async {
    try {
      await (await _prefs).setString(_themeKey, name);
    } on Exception catch (e) {
      throw StorageException(e.toString());
    }
  }
}
