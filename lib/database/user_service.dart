import 'package:intl/intl.dart';
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
    final hasSpecialCharacters = password.contains(
      RegExp(r'[!@#$%^&*(),.?":{}|<>]'),
    );

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

  // Funcion auxiliar para formatear la fecha ISO en un texto legible y amigable
  String _formatReadableDate(String isoDateString) {
    if (isoDateString.isEmpty) return 'Primer acceso';

    try {
      final DateTime parsedDate = DateTime.parse(isoDateString);
      final String formattedDate = DateFormat(
        'dd/MM/yyyy',
        'es_ES',
      ).format(parsedDate);
      final String formattedTime = DateFormat(
        'h:mm a',
        'en_US',
      ).format(parsedDate);

      final String period = formattedTime.endsWith('AM') ? 'a.m.' : 'p.m.';
      final String time = formattedTime.replaceAll(RegExp(r' AM| PM'), '');

      return '$formattedDate a las $time $period';
    } catch (e) {
      return isoDateString;
    }
  }

  // Autenticacion de usuario en la base de datos con recuperacion y actualizacion atomica de ultimo acceso
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
      final Map<String, dynamic> userMap = Map<String, dynamic>.from(
        result.first,
      );

      // Capturamos la fecha de acceso almacenada previamente (acceso anterior)
      final String rawLastAccess = userMap['last_access_date'] as String? ?? '';

      // Ejecucion transaccional atomica para registrar el acceso actual antes de retornar
      await db.transaction((txn) async {
        final String currentTimestamp = DateTime.now().toIso8601String();

        await txn.update(
          'users',
          {'last_access_date': currentTimestamp},
          where: 'id = ?',
          whereArgs: [userMap['id']],
        );
      });

      // Transformamos el valor al formato legible despues de realizar la actualizacion atomica
      userMap['last_access_date'] = _formatReadableDate(rawLastAccess);

      final User user = User.fromMap(userMap);

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
      final Map<String, dynamic> userMap = Map<String, dynamic>.from(
        result.first,
      );
      userMap['last_access_date'] = _formatReadableDate(
        userMap['last_access_date'] as String? ?? '',
      );
      return User.fromMap(userMap);
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