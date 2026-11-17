import 'package:intl/intl.dart';
import '../models/user.dart';
import '../services/session_manager.dart';
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

  // Conversion de cadenas de fecha almacenadas a objeto DateTime
  DateTime? _parseStoredDateTime(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) return null;

    final DateTime? isoParsed = DateTime.tryParse(trimmed);
    if (isoParsed != null) {
      return isoParsed.toLocal();
    }

    final RegExp dmyPattern = RegExp(
      r'^(\d{1,2})/(\d{1,2})/(\d{2,4})(?:(?:\s+a\s+las\s+|[ T]+)(\d{1,2}):(\d{2})(?::(\d{2}))?(?:\s*([AaPp]\.?[Mm]\.?))?)?$',
      caseSensitive: false,
    );
    final match = dmyPattern.firstMatch(trimmed);
    if (match != null) {
      final int day = int.parse(match.group(1)!);
      final int month = int.parse(match.group(2)!);
      int year = int.parse(match.group(3)!);
      if (year < 100) {
        year += 2000;
      }
      int hour = match.group(4) != null ? int.parse(match.group(4)!) : 0;
      final int minute =
      match.group(5) != null ? int.parse(match.group(5)!) : 0;
      final int second =
      match.group(6) != null ? int.parse(match.group(6)!) : 0;
      final String? meridiem = match.group(7)?.toUpperCase().replaceAll('.', '');

      if (meridiem == 'PM' && hour < 12) {
        hour += 12;
      } else if (meridiem == 'AM' && hour == 12) {
        hour = 0;
      }

      final DateTime candidate = DateTime(year, month, day, hour, minute, second);
      if (candidate.year == year &&
          candidate.month == month &&
          candidate.day == day) {
        return candidate;
      }
    }

    return null;
  }

  // Formateo unificado de fecha en formato dd/MM/yyyy
  String _formatUnifiedDate(String rawDateString, {String emptyFallback = ''}) {
    if (rawDateString.trim().isEmpty) return emptyFallback;

    try {
      final DateTime? parsedDate = _parseStoredDateTime(rawDateString);
      if (parsedDate == null) return rawDateString;

      return DateFormat('dd/MM/yyyy').format(parsedDate);
    } catch (_) {
      return rawDateString;
    }
  }

  // Formateo de fecha y hora del ultimo acceso en formato de 12 horas
  String _formatLastAccessDateTime(
      String rawDateString, {
        String emptyFallback = 'Primer acceso',
      }) {
    final String trimmed = rawDateString.trim();
    if (trimmed.isEmpty) return emptyFallback;

    try {
      final DateTime? parsedDate = _parseStoredDateTime(trimmed);
      if (parsedDate == null) return trimmed;

      final DateTime localDate = parsedDate.toLocal();
      final String day = localDate.day.toString().padLeft(2, '0');
      final String month = localDate.month.toString().padLeft(2, '0');
      final String year = localDate.year.toString().padLeft(4, '0');

      final bool hasTimeComponent =
          trimmed.contains(':') || trimmed.contains('T');
      if (!hasTimeComponent) {
        return '$day/$month/$year';
      }

      final int hour24 = localDate.hour;
      final int hour12 =
      hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
      final String minute = localDate.minute.toString().padLeft(2, '0');
      final String period = hour24 >= 12 ? 'P.M.' : 'A.M.';

      return '$day/$month/$year a las $hour12:$minute $period';
    } catch (_) {
      return trimmed;
    }
  }

  // Autenticacion de usuario en la base de datos con registro atomico de ultimo acceso
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

      final String rawBirthDate = userMap['birth_date'] as String? ?? '';
      final String userCode = (userMap['code'] as String? ?? '').trim();
      final String userRole =
      (userMap['role'] as String? ?? 'Visitante').trim();

      // Verificacion de prefijo de codigo segun el rol del usuario o la pestaña
      if (!isValidRoleCode(userCode, selectedRole) &&
          !isValidRoleCode(userCode, userRole)) {
        return null;
      }

      // Ejecucion transaccional atomica para registrar fecha y hora del acceso actual
      final String currentTimestamp = DateTime.now().toIso8601String();
      await db.transaction((txn) async {
        await txn.update(
          'users',
          {'last_access_date': currentTimestamp},
          where: 'id = ?',
          whereArgs: [userMap['id']],
        );
      });

      if (userCode.isNotEmpty) {
        await SessionManager.savePreviousLastAccess(userCode, currentTimestamp);
      }

      // Transformamos el ultimo acceso con fecha y hora y el nacimiento como fecha
      userMap['last_access_date'] = _formatLastAccessDateTime(
        currentTimestamp,
        emptyFallback: 'Primer acceso',
      );
      userMap['birth_date'] = _formatUnifiedDate(rawBirthDate);

      return User.fromMap(userMap);
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
      final String userCode = (userMap['code'] as String? ?? '').trim();
      final String dbLastAccess =
      (userMap['last_access_date'] as String? ?? '').trim();
      final String? sessionLastAccess = userCode.isNotEmpty
          ? await SessionManager.getPreviousLastAccess(userCode)
          : null;
      final String effectiveLastAccess =
      dbLastAccess.isNotEmpty ? dbLastAccess : (sessionLastAccess ?? '');
      final String rawBirthDate = userMap['birth_date'] as String? ?? '';

      userMap['last_access_date'] = _formatLastAccessDateTime(
        effectiveLastAccess,
        emptyFallback: 'Primer acceso',
      );
      userMap['birth_date'] = _formatUnifiedDate(rawBirthDate);
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

  // Verificacion de existencia de correo en otro registro de la base de datos
  Future<bool> isEmailInUseByOtherUser({
    required String email,
    required String currentUserCode,
  }) async {
    final db = await _articleService.database;
    final result = await db.query(
      'users',
      columns: ['id'],
      where: 'LOWER(TRIM(email)) = ? AND UPPER(TRIM(code)) != ?',
      whereArgs: [
        email.trim().toLowerCase(),
        currentUserCode.trim().toUpperCase(),
      ],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  // Verificacion de existencia de documento en otro registro de la base de datos
  Future<bool> isDocumentNumberInUseByOtherUser({
    required String documentNumber,
    required String currentUserCode,
  }) async {
    final db = await _articleService.database;
    final result = await db.query(
      'users',
      columns: ['id'],
      where: 'LOWER(TRIM(document_number)) = ? AND UPPER(TRIM(code)) != ?',
      whereArgs: [
        documentNumber.trim().toLowerCase(),
        currentUserCode.trim().toUpperCase(),
      ],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  // Actualizacion transaccional de los datos personales en la base de datos
  Future<bool> updateUserEditableInfo({
    required String userCode,
    required String firstName,
    required String lastName,
    required String documentNumber,
    required String email,
    required String birthDate,
  }) async {
    final String cleanCode = userCode.trim();
    final String cleanFirstName = firstName.trim();
    final String cleanLastName = lastName.trim();
    final String cleanDocumentNumber = documentNumber.trim();
    final String cleanEmail = email.trim();
    final String cleanBirthDate = birthDate.trim();

    if (cleanCode.isEmpty ||
        cleanFirstName.isEmpty ||
        cleanLastName.isEmpty ||
        cleanDocumentNumber.isEmpty ||
        cleanEmail.isEmpty ||
        cleanBirthDate.isEmpty) {
      return false;
    }

    final db = await _articleService.database;

    final int updatedRows = await db.transaction((txn) async {
      return await txn.update(
        'users',
        {
          'first_name': cleanFirstName,
          'last_name': cleanLastName,
          'document_number': cleanDocumentNumber,
          'email': cleanEmail,
          'birth_date': cleanBirthDate,
        },
        where: 'code = ?',
        whereArgs: [cleanCode],
      );
    });

    return updatedRows > 0;
  }
}