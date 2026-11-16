import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/persistence_service.dart';

class SessionManager {
  static final ValueNotifier<String?> activeUserCode = ValueNotifier<String?>(null);
  static final PersistenceService _persistenceService = PersistenceService();
  static const String _userCodeKey = 'user_code';
  static const String _prevAccessPrefix = 'happiley_prev_access_';
  static final Map<String, String> _previousLastAccessCache = {};

  static bool get isLoggedIn => activeUserCode.value != null;

  static Future<void> loadSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_userCodeKey);
    activeUserCode.value = savedCode;
    if (savedCode != null && savedCode.isNotEmpty) {
      final key = '$_prevAccessPrefix${savedCode.trim().toUpperCase()}';
      if (prefs.containsKey(key)) {
        _previousLastAccessCache[savedCode.trim().toUpperCase()] =
            prefs.getString(key) ?? '';
      }
    }
  }

  static Future<void> savePreviousLastAccess(
      String userCode,
      String rawLastAccess,
      ) async {
    final normalizedCode = userCode.trim().toUpperCase();
    if (normalizedCode.isEmpty) return;
    _previousLastAccessCache[normalizedCode] = rawLastAccess;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prevAccessPrefix$normalizedCode', rawLastAccess);
  }

  static Future<String?> getPreviousLastAccess(String userCode) async {
    final normalizedCode = userCode.trim().toUpperCase();
    if (normalizedCode.isEmpty) return null;
    if (_previousLastAccessCache.containsKey(normalizedCode)) {
      return _previousLastAccessCache[normalizedCode];
    }
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prevAccessPrefix$normalizedCode';
    if (prefs.containsKey(key)) {
      final stored = prefs.getString(key) ?? '';
      _previousLastAccessCache[normalizedCode] = stored;
      return stored;
    }
    return null;
  }

  static Future<void> saveSession(String userCode) async {
    await _persistenceService.saveUserSession(userCode);
    activeUserCode.value = userCode;
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    final currentCode = activeUserCode.value;
    if (currentCode != null && currentCode.isNotEmpty) {
      final normalizedCode = currentCode.trim().toUpperCase();
      _previousLastAccessCache.remove(normalizedCode);
      await prefs.remove('$_prevAccessPrefix$normalizedCode');
    }
    await prefs.remove(_userCodeKey);
    activeUserCode.value = null;
  }
}