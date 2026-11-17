import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/article.dart';

// Gestion de operaciones en la base de datos del catalogo
class ArticleService {
  static Database? _database;

  // Obtencion de la instancia de la base de datos
  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  // Inicializacion de la base de datos
  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'happiley.db');

    final exists = await databaseExists(path);

    if (!exists) {
      final data = await rootBundle.load(
        'lib/database/happiley.db',
      );

      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      await File(path).writeAsBytes(
        bytes,
        flush: true,
      );
    }

    final db = await openDatabase(path);
    await ensureSavedItemsTable(db);
    await ensureSellerOwnershipSchema(db);
    return db;
  }

  // Creacion segura de la tabla de lista de deseos sin afectar registros existentes
  Future<void> ensureSavedItemsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS saved_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_code TEXT NOT NULL,
        article_id INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(user_code, article_id)
      )
    ''');
  }

  // Verificacion y creacion segura de la columna de propiedad del vendedor
  Future<void> ensureSellerOwnershipSchema(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(articles)');
    final hasSellerCode = columns.any(
          (col) => col['name']?.toString().toLowerCase() == 'seller_code',
    );

    if (!hasSellerCode) {
      await db.execute('ALTER TABLE articles ADD COLUMN seller_code TEXT');
    }
  }

  // Obtencion de todos los articulos
  Future<List<Article>> getArticles() async {
    final db = await database;
    await ensureSellerOwnershipSchema(db);

    final result = await db.query(
      'articles',
      orderBy: 'id DESC',
    );

    return result
        .map((article) => Article.fromMap(article))
        .toList();
  }

  // Obtencion exclusiva de los articulos publicados por un vendedor
  Future<List<Article>> getSellerArticles(String sellerCode) async {
    final normalizedCode = sellerCode.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      return [];
    }

    final db = await database;
    await ensureSellerOwnershipSchema(db);

    final result = await db.query(
      'articles',
      where: 'UPPER(TRIM(seller_code)) = ?',
      whereArgs: [normalizedCode],
      orderBy: 'id DESC',
    );

    return result
        .map((article) => Article.fromMap(article))
        .toList();
  }

  // Adicion de articulo
  Future<int> addArticle(Article article) async {
    final db = await database;
    await ensureSellerOwnershipSchema(db);

    return await db.insert(
      'articles',
      {
        'code': article.code,
        'name': article.name,
        'description': article.description,
        'purchase_price': article.purchasePrice,
        'sale_price': article.salePrice,
        'stock': article.stock,
        'purchase_date': article.purchaseDate,
        'sale_date': article.saleDate,
        'units_until_reorder': article.unitsUntilReorder,
        'support_end_date': article.supportEndDate,
        'image': article.image,
        'seller_code': article.sellerCode?.trim().toUpperCase(),
      },
    );
  }

  // Actualizacion de articulo
  Future<int> updateArticle(Article article) async {
    final db = await database;
    await ensureSellerOwnershipSchema(db);

    return await db.update(
      'articles',
      {
        'code': article.code,
        'name': article.name,
        'description': article.description,
        'purchase_price': article.purchasePrice,
        'sale_price': article.salePrice,
        'stock': article.stock,
        'purchase_date': article.purchaseDate,
        'sale_date': article.saleDate,
        'units_until_reorder': article.unitsUntilReorder,
        'support_end_date': article.supportEndDate,
        'image': article.image,
        'seller_code': article.sellerCode?.trim().toUpperCase(),
      },
      where: 'id = ?',
      whereArgs: [article.id],
    );
  }

  // Eliminacion segura de articulo verificando propiedad del vendedor y archivos asociados
  Future<bool> deleteSellerArticle({
    required int articleId,
    required String sellerCode,
  }) async {
    final normalizedCode = sellerCode.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      return false;
    }

    try {
      final db = await database;
      await ensureSellerOwnershipSchema(db);
      await ensureSavedItemsTable(db);

      final existingRows = await db.query(
        'articles',
        columns: ['id', 'image'],
        where: 'id = ? AND UPPER(TRIM(seller_code)) = ?',
        whereArgs: [articleId, normalizedCode],
        limit: 1,
      );

      if (existingRows.isEmpty) {
        return false;
      }

      final String? imagePath = existingRows.first['image']?.toString();

      final deletedCount = await db.delete(
        'articles',
        where: 'id = ? AND UPPER(TRIM(seller_code)) = ?',
        whereArgs: [articleId, normalizedCode],
      );

      if (deletedCount <= 0) {
        return false;
      }

      await db.delete(
        'saved_items',
        where: 'article_id = ?',
        whereArgs: [articleId],
      );

      await deleteUnreferencedLocalImage(db, imagePath);
      return true;
    } catch (e) {
      debugPrint('Error al eliminar articulo del vendedor: $e');
      return false;
    }
  }

  // Eliminacion fisica de imagen local solo cuando ningun otro registro la utiliza
  Future<void> deleteUnreferencedLocalImage(
      Database db,
      String? imagePath,
      ) async {
    if (imagePath == null || imagePath.trim().isEmpty) {
      return;
    }

    final cleanPath = imagePath.trim();
    if (cleanPath.startsWith('lib/assets/') ||
        cleanPath.startsWith('assets/')) {
      return;
    }

    final referencesQuery = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM articles WHERE image = ?',
      [cleanPath],
    );
    final int remainingRefs = Sqflite.firstIntValue(referencesQuery) ?? 0;

    if (remainingRefs == 0) {
      final file = File(cleanPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  // Eliminacion de articulo
  Future<int> deleteArticle(int id) async {
    final db = await database;

    return await db.delete(
      'articles',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}