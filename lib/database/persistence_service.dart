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
        // Creacion de la tabla para los articulos del carrito
        await db.execute('''
          CREATE TABLE IF NOT EXISTS cart_items (
            id INTEGER PRIMARY KEY
          )
        ''');

        // Creacion de la tabla para el manejo de la sesion activa
        await db.execute('''
          CREATE TABLE IF NOT EXISTS session (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            user_code TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // Verificacion de la existencia de las tablas en la base de datos
  Future<void> _ensureTablesExist(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cart_items (
        id INTEGER PRIMARY KEY
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS session (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        user_code TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  // Obtencion de identificadores del carrito
  Future<List<int>> getSavedCartIds() async {
    final db = await database;
    await _ensureTablesExist(db);

    final result = await db.query('cart_items');

    return result
        .map((item) => item['id'] as int)
        .toList();
  }

  // Insercion de articulo en el carrito
  Future<void> insertCartItem(int id) async {
    final db = await database;
    await _ensureTablesExist(db);

    await db.insert(
      'cart_items',
      {'id': id},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Eliminacion de articulo del carrito
  Future<void> deleteCartItem(int id) async {
    final db = await database;
    await _ensureTablesExist(db);

    await db.delete(
      'cart_items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Limpieza de la tabla del carrito
  Future<void> clearCartTable() async {
    final db = await database;
    await _ensureTablesExist(db);

    await db.delete('cart_items');
  }

  // Guardar o reemplazar el codigo del usuario en la sesion activa
  Future<void> saveUserSession(String userCode) async {
    final db = await database;
    await _ensureTablesExist(db);

    final now = DateTime.now().toIso8601String();

    await db.insert(
      'session',
      {
        'id': 1,
        'user_code': userCode,
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Obtener el codigo de usuario almacenado
  Future<String?> getActiveUserCode() async {
    final db = await database;
    await _ensureTablesExist(db);

    final List<Map<String, dynamic>> results = await db.query(
      'session',
      where: 'id = ?',
      whereArgs: [1],
    );

    if (results.isNotEmpty) {
      return results.first['user_code'] as String?;
    }
    return null;
  }

  // Borrar el registro de la tabla session
  Future<void> clearSessionTable() async {
    final db = await database;
    await _ensureTablesExist(db);

    await db.delete('session');
  }
}