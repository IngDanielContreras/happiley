import 'package:flutter/material.dart';
import '../models/article.dart';
import '../database/article_service.dart';
import '../database/persistence_service.dart';

// Administracion del carrito con persistencia en base de datos independiente
class CartManager {
  // Notificacion de cambios en la seleccion
  static final ValueNotifier<List<Article>> selectedArticles = ValueNotifier(
      []);

  // Instanciacion de los servicios de base de datos
  static final ArticleService _articleService = ArticleService();
  static final PersistenceService _persistenceService = PersistenceService();

  // Carga de articulos guardados desde persistence.db
  static Future<void> loadSavedCart() async {
    try {
      final savedIds = await _persistenceService.getSavedCartIds();

      if (savedIds.isNotEmpty) {
        final allArticles = await _articleService.getArticles();

        // Filtrado de articulos coincidentes
        final loadedArticles = allArticles.where((article) {
          return savedIds.contains(article.id);
        }).toList();

        selectedArticles.value = loadedArticles;
      }
    } catch (e) {
      debugPrint('Error en carga del carrito: $e');
    }
  }

  // Alternancia de seleccion del producto
  static void toggleProduct(Article article) {
    if (isSelected(article)) {
      // Eliminacion del articulo seleccionado
      selectedArticles.value = selectedArticles.value
          .where((item) => item.id != article.id)
          .toList();

      // Remocion del registro en persistence.db
      _persistenceService.deleteCartItem(article.id);
    } else {
      // Adicion del nuevo articulo
      selectedArticles.value = [...selectedArticles.value, article];

      // Insercion del registro en persistence.db
      _persistenceService.insertCartItem(article.id);
    }
  }

  // Consulta de seleccion del articulo
  static bool isSelected(Article article) {
    return selectedArticles.value.any((item) => item.id == article.id);
  }

  // Limpieza total del carrito en persistence.db
  static void clearCart() {
    selectedArticles.value = [];
    _persistenceService.clearCartTable();
  }
}