import '../models/user.dart';
import 'article_service.dart';

class UserService {
  final ArticleService _articleService = ArticleService();

  // Validacion de las politicas de contraseña
  bool validatePasswordPolicies(String password) {
    if (password.length < 8) return false;
    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasLowercase = password.contains(RegExp(r'[a-z]'));
    final hasDigits = password.contains(RegExp(r'[0-9]'));
    final hasSpecialCharacters =
    password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    return hasUppercase && hasLowercase && hasDigits && hasSpecialCharacters;
  }

  // Verificacion de rol y prefijo
  bool isValidRoleCode(String code, String role) {
    final cleanRole = role.toLowerCase().trim();
    if ((cleanRole == 'administrador' || cleanRole == 'admin') &&
        code.startsWith('AUR')) {
      return true;
    }
    if (cleanRole == 'vendedor' && code.startsWith('SUR')) return true;
    if (cleanRole == 'visitante' && code.startsWith('VUR')) return true;
    return false;
  }

  // Autenticacion de usuario en la base de datos
  Future<User?> loginUser({
    required String email,
    required String password,
    required String selectedRole,
  }) async {
    final db = await _articleService.database;

    // Verificacion directa de credenciales en la base de datos
    final result = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email.trim(), password],
    );

    if (result.isNotEmpty) {
      final user = User.fromMap(result.first);

      // Verificacion de prefijo de codigo segun el rol del usuario o la pestaña
      if (isValidRoleCode(user.code, selectedRole) ||
          isValidRoleCode(user.code, user.role)) {
        return user;
      }
    }
    return null;
  }

  // Obtencion de usuario por identificador
  Future<User?> getUserById(dynamic identifier) async {
    final db = await _articleService.database;
    final String searchVal = identifier.toString();

    final result = await db.query(
      'users',
      where: 'code = ? OR id = ?',
      whereArgs: [searchVal, searchVal],
    );

    if (result.isNotEmpty) {
      return User.fromMap(result.first);
    }
    return null;
  }

  // Actualizacion de la ruta de la imagen del usuario
  Future<void> updateUserImage(dynamic userCode, String imagePath) async {
    final db = await _articleService.database;
    final String searchVal = userCode.toString();

    await db.update(
      'users',
      {'image': imagePath},
      where: 'code = ? OR id = ?',
      whereArgs: [searchVal, searchVal],
    );
  }
}