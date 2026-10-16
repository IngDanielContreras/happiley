import 'package:shared_preferences/shared_preferences.dart';

class PersistenceService {
  static const String _cartKey = 'cart_items';
  static const String _sessionKey = 'user_code';

  // Obtencion de identificadores del carrito
  Future<List<int>> getSavedCartIds() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? cartList = prefs.getStringList(_cartKey);
    if (cartList != null) {
      return cartList.map((id) => int.parse(id)).toList();
    }
    return [];
  }

  // Insercion de articulo en el carrito
  Future<void> insertCartItem(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final currentIds = await getSavedCartIds();
    if (!currentIds.contains(id)) {
      currentIds.add(id);
      await prefs.setStringList(
        _cartKey,
        currentIds.map((e) => e.toString()).toList(),
      );
    }
  }

  // Eliminacion de articulo del carrito
  Future<void> deleteCartItem(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final currentIds = await getSavedCartIds();
    currentIds.remove(id);
    await prefs.setStringList(
      _cartKey,
      currentIds.map((e) => e.toString()).toList(),
    );
  }

  // Limpieza de la tabla del carrito
  Future<void> clearCartTable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cartKey);
  }

  // Almacenamiento o reemplazo del codigo del usuario en la sesion activa
  Future<void> saveUserSession(String userCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, userCode);
  }

  // Obtener el codigo de usuario almacenado
  Future<String?> getActiveUserCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sessionKey);
  }

  // Borrar el registro de la tabla session
  Future<void> clearSessionTable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  // Validacion de credenciales de usuario para el inicio de sesion
  Future<bool> validateUserCredentials(String user, String password) async {
    if (user.isNotEmpty && password.isNotEmpty) {
      return true;
    }
    return false;
  }
}