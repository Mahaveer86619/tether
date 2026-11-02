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
  static const _fingerprintKey = 'hub_fingerprint';
  static const _tailnetKey = 'hub_via_tailnet';
  static const _themeKey = 'theme_mode';
  static const _paletteKey = 'theme_palette';
  static const _accentKey = 'theme_accent';

  final FlutterSecureStorage _secure;
  final Map<String, String> _env;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<(String url, String token, String fingerprint, bool viaTailnet)> readConnection() async {
    try {
      final prefs = await _prefs;
      var url = prefs.getString(_urlKey) ?? '';
      final fingerprint = prefs.getString(_fingerprintKey) ?? '';
      var token = '';
      try {
        token = await _secure.read(key: _tokenKey) ?? '';
      } on Exception {
        // A keystore wiped by reinstalling the app can't be read; ask again.
      }
      // Desktop convenience: the same variables tetherctl uses.
      if (url.isEmpty) url = _env['TETHER_HUB'] ?? '';
      if (token.isEmpty) token = _env['TETHER_TOKEN'] ?? '';
      return (url, token, fingerprint, prefs.getBool(_tailnetKey) ?? false);
    } on Exception catch (e) {
      throw StorageException(e.toString());
    }
  }

  Future<void> writeConnection(String url, String token, String fingerprint, {bool viaTailnet = false}) async {
    try {
      await (await _prefs).setString(_urlKey, url);
      await (await _prefs).setBool(_tailnetKey, viaTailnet);
      await (await _prefs).setString(_fingerprintKey, fingerprint);
      await _secure.write(key: _tokenKey, value: token);
    } on Exception catch (e) {
      throw StorageException(e.toString());
    }
  }

  Future<void> clearConnection() async {
    try {
      final prefs = await _prefs;
      await prefs.remove(_urlKey);
      await prefs.remove(_tailnetKey);
      await prefs.remove(_fingerprintKey);
      await _secure.delete(key: _tokenKey);
    } on Exception catch (e) {
      throw StorageException(e.toString());
    }
  }

  Future<(String? mode, String? palette, int? accent)> readAppearance() async {
    try {
      final prefs = await _prefs;
      return (prefs.getString(_themeKey), prefs.getString(_paletteKey), prefs.getInt(_accentKey));
    } on Exception {
      return (null, null, null);
    }
  }

  /// Unsent text in a message box, kept across restarts.
  Future<String> readDraft(String key) async {
    try {
      return (await _prefs).getString('draft:$key') ?? '';
    } on Exception {
      return '';
    }
  }

  Future<void> writeDraft(String key, String text) async {
    try {
      final prefs = await _prefs;
      text.trim().isEmpty ? await prefs.remove('draft:$key') : await prefs.setString('draft:$key', text);
    } on Exception {
      // A lost draft isn't worth an error.
    }
  }

  /// A small value kept on the device, e.g. a skipped update.
  Future<String> readValue(String key) async {
    try {
      return (await _prefs).getString(key) ?? '';
    } on Exception {
      return '';
    }
  }

  Future<void> writeValue(String key, String value) async {
    try {
      await (await _prefs).setString(key, value);
    } on Exception {
      // Asked again next time; nothing is lost.
    }
  }

  /// A session's outbox as JSON, kept across restarts.
  Future<String> readOutbox(String session) async {
    try {
      return (await _prefs).getString('outbox:$session') ?? '';
    } on Exception {
      return '';
    }
  }

  Future<void> writeOutbox(String session, String json) async {
    try {
      final prefs = await _prefs;
      json.isEmpty ? await prefs.remove('outbox:$session') : await prefs.setString('outbox:$session', json);
    } on Exception {
      // The next write tries again; the message is also still on screen.
    }
  }

  Future<void> writeAppearance(String mode, String palette, int? accent) async {
    try {
      final prefs = await _prefs;
      await prefs.setString(_themeKey, mode);
      await prefs.setString(_paletteKey, palette);
      if (accent == null) {
        await prefs.remove(_accentKey);
      } else {
        await prefs.setInt(_accentKey, accent);
      }
    } on Exception catch (e) {
      throw StorageException(e.toString());
    }
  }
}
