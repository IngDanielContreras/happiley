import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../models/article.dart';
import '../database/article_service.dart';
import 'session_manager.dart';

// Administracion de la lista de deseos con persistencia por usuario en SQLite
class SavedItemsManager {
  // Notificacion reactiva de los articulos guardados del usuario activo
  static final ValueNotifier<List<Article>> savedArticles = ValueNotifier(
    [],
  );

  static final ArticleService _articleService = ArticleService();
  static bool _isInitialized = false;

  // Inicializacion del gestor y escucha de cambios de sesion activa
  static Future<void> initialize() async {
    if (!_isInitialized) {
      _isInitialized = true;
      SessionManager.activeUserCode.addListener(_handleSessionChanged);
    }

    await loadSavedItems();
  }

  // Sincronizacion automatica al iniciar o cerrar sesion
  static void _handleSessionChanged() {
    final String? userCode = SessionManager.activeUserCode.value;
    if (userCode == null || userCode.trim().isEmpty) {
      savedArticles.value = [];
    } else {
      loadSavedItemsForUser(userCode);
    }
  }

  // Carga de los articulos guardados para el usuario autenticado actual
  static Future<void> loadSavedItems() async {
    final String? userCode = SessionManager.activeUserCode.value;
    if (userCode == null || userCode.trim().isEmpty) {
      savedArticles.value = [];
      return;
    }

    await loadSavedItemsForUser(userCode);
  }

  // Recuperacion desde la base de datos de los articulos asociados a un codigo de usuario
  static Future<void> loadSavedItemsForUser(String userCode) async {
    final String normalizedCode = userCode.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      savedArticles.value = [];
      return;
    }

    try {
      final db = await _articleService.database;
      await _articleService.ensureSavedItemsTable(db);

      final result = await db.rawQuery(
        '''
        SELECT a.*
        FROM articles a
        INNER JOIN saved_items s ON a.id = s.article_id
        WHERE UPPER(TRIM(s.user_code)) = ?
        ORDER BY s.id DESC
        ''',
        [normalizedCode],
      );

      final List<Article> loadedArticles =
      result.map((row) => Article.fromMap(row)).toList();

      if (SessionManager.activeUserCode.value?.trim().toUpperCase() ==
          normalizedCode) {
        savedArticles.value = loadedArticles;
      }
    } catch (e) {
      debugPrint('Error al cargar la lista de deseos: $e');
    }
  }

  // Consulta del estado de guardado del articulo en memoria sincronizada
  static bool isSaved(Article article) {
    return savedArticles.value.any((item) => item.id == article.id);
  }

  // Alternancia persistente del articulo en la lista de deseos del usuario
  static Future<bool> toggleSavedItem(Article article) async {
    if (isSaved(article)) {
      return await removeSavedItem(article);
    } else {
      return await addSavedItem(article);
    }
  }

  // Insercion sin duplicados del articulo en la tabla saved_items
  static Future<bool> addSavedItem(Article article) async {
    final String? rawUserCode = SessionManager.activeUserCode.value;
    if (rawUserCode == null || rawUserCode.trim().isEmpty) {
      return false;
    }

    final String normalizedCode = rawUserCode.trim().toUpperCase();

    try {
      final db = await _articleService.database;
      await _articleService.ensureSavedItemsTable(db);

      await db.insert(
        'saved_items',
        {
          'user_code': normalizedCode,
          'article_id': article.id,
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      if (!isSaved(article)) {
        savedArticles.value = [article, ...savedArticles.value];
      }

      return true;
    } catch (e) {
      debugPrint('Error al guardar articulo en lista de deseos: $e');
      return false;
    }
  }

  // Eliminacion del articulo de la tabla saved_items para el usuario activo
  static Future<bool> removeSavedItem(Article article) async {
    final String? rawUserCode = SessionManager.activeUserCode.value;
    if (rawUserCode == null || rawUserCode.trim().isEmpty) {
      return false;
    }

    final String normalizedCode = rawUserCode.trim().toUpperCase();

    try {
      final db = await _articleService.database;
      await _articleService.ensureSavedItemsTable(db);

      await db.delete(
        'saved_items',
        where: 'UPPER(TRIM(user_code)) = ? AND article_id = ?',
        whereArgs: [normalizedCode, article.id],
      );

      savedArticles.value = savedArticles.value
          .where((item) => item.id != article.id)
          .toList();

      return true;
    } catch (e) {
      debugPrint('Error al eliminar articulo de lista de deseos: $e');
      return false;
    }
  }
}