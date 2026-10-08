import 'package:flutter/material.dart';
import '../database/persistence_service.dart';

// Administracion de la sesion del usuario con persistencia en persistence.db
class SessionManager {
  // Notificacion de cambios en el codigo de usuario activo
  static final ValueNotifier<String?> activeUserCode = ValueNotifier(null);

  // Instanciacion del servicio de base de datos
  static final PersistenceService _persistenceService = PersistenceService();

  // Carga del usuario guardado desde persistence.db
  static Future<void> loadSavedSession() async {
    try {
      final userCode = await _persistenceService.getActiveUserCode();
      activeUserCode.value = userCode;
    } catch (e) {
      debugPrint('Error en carga de la sesion: $e');
    }
  }

  // Guardar la sesion cuando el usuario inicia sesion
  static Future<void> saveSession(String userCode) async {
    try {
      activeUserCode.value = userCode;
      await _persistenceService.saveUserSession(userCode);
    } catch (e) {
      debugPrint('Error al guardar la sesion: $e');
    }
  }

  // Limpieza total de la sesion al cerrar sesion
  static Future<void> clearSession() async {
    try {
      activeUserCode.value = null;
      await _persistenceService.clearSessionTable();
    } catch (e) {
      debugPrint('Error al cerrar la sesion: $e');
    }
  }

  // Consulta rapida del estado de la sesion
  static bool get isLoggedIn => activeUserCode.value != null;
}