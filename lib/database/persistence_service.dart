import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

// Gestion de operaciones en la base de datos de persistencia
class PersistenceService {
  static Database? _database;

  // Obtencion de la instancia de la base de datos
  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  // Inicializacion de la base de datos independiente
  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'persistence.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Aseguramiento de creacion de la tabla del carrito
        await db.execute('''
          CREATE TABLE IF NOT EXISTS cart_items (
            id INTEGER PRIMARY KEY
          )
        ''');
      },
    );
  }

  // Obtencion de identificadores del carrito
  Future<List<int>> getSavedCartIds() async {
    final db = await database;

    // Aseguramiento de creacion de la tabla si no existe
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cart_items (
        id INTEGER PRIMARY KEY
      )
    ''');

    final result = await db.query('cart_items');

    return result
        .map((item) => item['id'] as int)
        .toList();
  }

  // Insercion de articulo en el carrito
  Future<void> insertCartItem(int id) async {
    final db = await database;

    await db.insert(
      'cart_items',
      {'id': id},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Eliminacion de articulo del carrito
  Future<void> deleteCartItem(int id) async {
    final db = await database;

    await db.delete(
      'cart_items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Limpieza de la tabla del carrito
  Future<void> clearCartTable() async {
    final db = await database;

    await db.delete('cart_items');
  }
}