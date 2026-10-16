import '../database/database_helper.dart';

class UserService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Autenticacion de credenciales contra la tabla de usuarios
  Future<bool> authenticateUser(String user, String password) async {
    final db = await _dbHelper.database;

    final List<Map<String, dynamic>> results = await db.query(
      'users',
      where: '(username = ? OR email = ?) AND password = ?',
      whereArgs: [user, user, password],
    );

    return results.isNotEmpty;
  }
}