import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../database/article_service.dart';
import '../models/app_notification.dart';
import 'session_manager.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  NotificationService._internal() {
    SessionManager.activeUserCode.addListener(_onSessionChanged);
  }

  static const String _welcomeInitializedKey = 'happiley_welcome_notif_v1';

  final ArticleService _articleService = ArticleService();
  final ValueNotifier<List<AppNotification>> notificationsNotifier =
  ValueNotifier<List<AppNotification>>([]);
  final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  bool _tableReady = false;

  Future<Database> _getDb() async {
    final db = await _articleService.database;
    if (!_tableReady) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS notifications (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          subtitle TEXT NOT NULL,
          type TEXT NOT NULL,
          created_at TEXT NOT NULL,
          is_read INTEGER NOT NULL DEFAULT 0,
          user_code TEXT,
          reference_id TEXT
        )
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_notifications_user_code
        ON notifications (user_code)
      ''');
      _tableReady = true;
    }
    return db;
  }

  Future<void> initialize() async {
    try {
      final db = await _getDb();
      final prefs = await SharedPreferences.getInstance();
      final bool welcomeCreated =
          prefs.getBool(_welcomeInitializedKey) ?? false;

      if (!welcomeCreated) {
        final existingWelcome = await db.query(
          'notifications',
          where: 'type = ?',
          whereArgs: [AppNotificationType.welcome.name],
          limit: 1,
        );

        if (existingWelcome.isEmpty) {
          final welcomeNotification = AppNotification(
            title: 'Bienvenido a Happiley',
            subtitle:
            'Te invitamos a descubrir todos los productos que tenemos disponibles, recordando que hacerlo/a feliz es nuestra prioridad.',
            type: AppNotificationType.welcome,
            createdAt: DateTime.now(),
            isRead: false,
            userCode: null,
            referenceId: 'WELCOME_INIT',
          );
          await db.insert('notifications', welcomeNotification.toMap());
        }

        await prefs.setBool(_welcomeInitializedKey, true);
      }

      await refreshNotifications();
    } catch (e) {
      debugPrint('Error al inicializar sistema de notificaciones: $e');
    }
  }

  void _onSessionChanged() {
    refreshNotifications();
  }

  Future<void> refreshNotifications() async {
    try {
      final db = await _getDb();
      final String? currentUserCode = SessionManager.activeUserCode.value;

      final rows = (currentUserCode == null || currentUserCode.isEmpty)
          ? await db.query(
        'notifications',
        where: 'user_code IS NULL',
        orderBy: 'id DESC',
      )
          : await db.query(
        'notifications',
        where: 'user_code IS NULL OR user_code = ?',
        whereArgs: [currentUserCode],
        orderBy: 'id DESC',
      );

      final items = rows.map((row) => AppNotification.fromMap(row)).toList();
      notificationsNotifier.value = items;
      unreadCountNotifier.value = items.where((item) => !item.isRead).length;
    } catch (e) {
      debugPrint('Error al cargar notificaciones: $e');
    }
  }

  Future<void> addNotification({
    required String title,
    required String subtitle,
    required AppNotificationType type,
    String? userCode,
    String? referenceId,
  }) async {
    try {
      final db = await _getDb();
      final effectiveUserCode = userCode ?? SessionManager.activeUserCode.value;

      if (referenceId != null && referenceId.isNotEmpty) {
        final existing = await db.query(
          'notifications',
          where:
          'type = ? AND reference_id = ? AND (user_code = ? OR (user_code IS NULL AND ? IS NULL))',
          whereArgs: [
            type.name,
            referenceId,
            effectiveUserCode,
            effectiveUserCode,
          ],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          await refreshNotifications();
          return;
        }
      }

      final notification = AppNotification(
        title: title,
        subtitle: subtitle,
        type: type,
        createdAt: DateTime.now(),
        isRead: false,
        userCode: effectiveUserCode,
        referenceId: referenceId,
      );

      await db.insert('notifications', notification.toMap());
      await refreshNotifications();
    } catch (e) {
      debugPrint('Error al registrar notificacion: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final db = await _getDb();
      final String? currentUserCode = SessionManager.activeUserCode.value;

      if (currentUserCode == null || currentUserCode.isEmpty) {
        await db.update(
          'notifications',
          {'is_read': 1},
          where: 'user_code IS NULL AND is_read = 0',
        );
      } else {
        await db.update(
          'notifications',
          {'is_read': 1},
          where: '(user_code IS NULL OR user_code = ?) AND is_read = 0',
          whereArgs: [currentUserCode],
        );
      }

      await refreshNotifications();
    } catch (e) {
      debugPrint('Error al marcar notificaciones como leidas: $e');
    }
  }

  Future<void> markAsRead(int id) async {
    try {
      final db = await _getDb();
      await db.update(
        'notifications',
        {'is_read': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
      await refreshNotifications();
    } catch (e) {
      debugPrint('Error al marcar notificacion como leida: $e');
    }
  }

  Future<void> deleteNotification(int id) async {
    try {
      final db = await _getDb();
      await db.delete(
        'notifications',
        where: 'id = ?',
        whereArgs: [id],
      );
      await refreshNotifications();
    } catch (e) {
      debugPrint('Error al eliminar notificacion: $e');
    }
  }

  Future<void> notifyLoginSuccess(String userCode) async {
    await addNotification(
      title: 'Inicio de sesión exitoso',
      subtitle:
      'Has iniciado sesión correctamente. ¡Nos alegra tenerte de vuelta en Happiley!',
      type: AppNotificationType.loginSuccess,
      userCode: userCode,
    );
  }

  Future<void> notifyPurchaseSuccess({
    required String userCode,
    required String purchaseCode,
    required int totalItems,
    required String formattedTotal,
  }) async {
    await addNotification(
      title: '¡Compra realizada exitosamente!',
      subtitle:
      'Tu compra ($purchaseCode) por $totalItems artículo(s) ($formattedTotal) se ha procesado correctamente. Gracias por confiar en Happiley.',
      type: AppNotificationType.purchaseSuccess,
      userCode: userCode,
      referenceId: purchaseCode,
    );
  }

  Future<void> notifyPurchaseFailed({
    required String userCode,
    required String reason,
  }) async {
    await addNotification(
      title: 'No se pudo completar tu compra',
      subtitle:
      'Se presentó un inconveniente durante el proceso de compra: $reason Verifica la información e inténtalo nuevamente.',
      type: AppNotificationType.purchaseFailed,
      userCode: userCode,
    );
  }

  Future<void> notifyPublishSuccess({
    required String userCode,
    required String articleCode,
    required String articleName,
  }) async {
    await addNotification(
      title: '¡Artículo publicado exitosamente!',
      subtitle:
      'Tu artículo "$articleName" ($articleCode) se ha publicado correctamente y ahora está disponible en Happiley.',
      type: AppNotificationType.publishSuccess,
      userCode: userCode,
      referenceId: articleCode,
    );
  }

  Future<void> notifyPublishFailed({
    required String userCode,
    required String reason,
  }) async {
    await addNotification(
      title: 'No se pudo publicar el artículo',
      subtitle:
      'Se presentó un inconveniente al publicar tu artículo: $reason Verifica la información e inténtalo nuevamente.',
      type: AppNotificationType.publishFailed,
      userCode: userCode,
    );
  }
}