import 'dart:io';
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

    return await openDatabase(path);
  }

  // Obtencion de todos los articulos
  Future<List<Article>> getArticles() async {
    final db = await database;

    final result = await db.query(
      'articles',
      orderBy: 'id DESC',
    );

    return result
        .map((article) => Article.fromMap(article))
        .toList();
  }

  // Adicion de articulo
  Future<int> addArticle(Article article) async {
    final db = await database;

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
      },
    );
  }

  // Actualizacion de articulo
  Future<int> updateArticle(Article article) async {
    final db = await database;

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
      },
      where: 'id = ?',
      whereArgs: [article.id],
    );
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