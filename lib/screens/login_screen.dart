import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/user_service.dart';
import '../services/session_manager.dart';
import '../widgets/loading_dialog.dart';


class LoginScreen extends StatefulWidget {
  final Function(String userCode)? onLoginSuccess;

  const LoginScreen({
    super.key,
    this.onLoginSuccess,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool obscurePassword = true;
  bool acceptPrivacy = false;
  bool rememberData = false;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final UserService _userService = UserService();

  late TabController _tabController;
  final List<String> _roles = ['Visitante', 'Vendedor', 'Admin'];

  int failedAttempts = 0;
  int lockoutLevel = 0;
  int remainingSeconds = 0;
  bool isPermanentlyBlocked24h = false;
  DateTime? unlockDateTime;
  Timer? lockoutTimer;

  static const String keyFailedAttempts = 'login_failed_attempts';
  static const String keyLockoutLevel = 'login_lockout_level';
  static const String keyLockoutEndTime = 'login_lockout_end_time';
  static const String keySavedEmail = 'login_saved_email';
  static const String keyRememberData = 'login_remember_data';
  static const int maxAttempts = 4;

  static const List<int> lockoutDurationsMinutes = [
    3,
    6,
    9,
    30,
    60,
    90,
    1440,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSavedUserData();
    _checkLockoutStatus();
  }

  // Recuperacion de datos de usuario almacenados localmente
  Future<void> _loadSavedUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final isRemembered = prefs.getBool(keyRememberData) ?? false;
    final savedEmail = prefs.getString(keySavedEmail) ?? '';

    if (isRemembered && savedEmail.isNotEmpty) {
      setState(() {
        rememberData = true;
        emailController.text = savedEmail;
      });
    }
  }

  // Almacenamiento de preferencias de sesion del usuario
  Future<void> _saveUserDataPreference(String email) async {
    final prefs = await SharedPreferences.getInstance();
    if (rememberData) {
      await prefs.setBool(keyRememberData, true);
      await prefs.setString(keySavedEmail, email);
    } else {
      await prefs.remove(keyRememberData);
      await prefs.remove(keySavedEmail);
    }
  }

  // Verificacion del estado de bloqueo temporal o permanente
  Future<void> _checkLockoutStatus() async {
    final prefs = await SharedPreferences.getInstance();
    failedAttempts = prefs.getInt(keyFailedAttempts) ?? 0;
    lockoutLevel = prefs.getInt(keyLockoutLevel) ?? 0;
    final lockoutEndTimeMs = prefs.getInt(keyLockoutEndTime) ?? 0;

    if (lockoutEndTimeMs > 0) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final diffSeconds = ((lockoutEndTimeMs - nowMs) / 1000).ceil();

      if (diffSeconds > 0) {
        unlockDateTime = DateTime.fromMillisecondsSinceEpoch(lockoutEndTimeMs);
        if (lockoutLevel >= lockoutDurationsMinutes.length) {
          isPermanentlyBlocked24h = true;
        }
        emailController.clear();
        passwordController.clear();
        _startLockoutTimer(diffSeconds);
      } else {
        await _clearLockoutTimerOnly();
      }
    }
  }

  // Inicializacion del temporizador de bloqueo por tiempo
  void _startLockoutTimer(int seconds) {
    setState(() {
      remainingSeconds = seconds;
    });

    lockoutTimer?.cancel();
    lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (remainingSeconds <= 1) {
        timer.cancel();
        await _clearLockoutTimerOnly();
      } else {
        setState(() {
          remainingSeconds--;
        });
      }
    });
  }

  // Limpieza exclusiva del temporizador de bloqueo activo
  Future<void> _clearLockoutTimerOnly() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyLockoutEndTime);
    await prefs.remove(keyFailedAttempts);

    lockoutTimer?.cancel();
    setState(() {
      failedAttempts = 0;
      remainingSeconds = 0;
      isPermanentlyBlocked24h = false;
      unlockDateTime = null;
    });
  }

  // Restablecimiento total de las politicas de seguridad de acceso
  Future<void> _resetFullSecurityPolicy() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyFailedAttempts);
    await prefs.remove(keyLockoutLevel);
    await prefs.remove(keyLockoutEndTime);

    lockoutTimer?.cancel();
    setState(() {
      failedAttempts = 0;
      lockoutLevel = 0;
      remainingSeconds = 0;
      isPermanentlyBlocked24h = false;
      unlockDateTime = null;
    });
  }

  // Formateo de fecha y hora para el desbloqueo del sistema
  String _formatUnlockDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year a las $hour:$minute';
  }

  // Gestion de intentos fallidos y aplicacion de penalizaciones
  Future<void> _handleFailedAttemptAfterDialog() async {
    failedAttempts++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyFailedAttempts, failedAttempts);

    if (failedAttempts == 3) {
      if (!mounted) return;

      final currentDurationMin = lockoutDurationsMinutes[
      lockoutLevel.clamp(0, lockoutDurationsMinutes.length - 1)];

      await LoadingDialog.show(
        context,
        title: '¡Te Queda Un Solo Intento!',
        subtitle:
        'En caso de inicio de sesión fallido, debe esperar $currentDurationMin minutos y volver a intentarlo al finalizar el tiempo.',
        autoDismiss: true,
        duration: const Duration(seconds: 5),
        customIcon: const Icon(
          Icons.warning_amber_rounded,
          color: Color(0xFFFF9800),
          size: 56,
        ),
      );
    } else if (failedAttempts >= maxAttempts) {
      emailController.clear();
      passwordController.clear();

      final durationMinutes = lockoutDurationsMinutes[
      lockoutLevel.clamp(0, lockoutDurationsMinutes.length - 1)];
      final durationSeconds = durationMinutes * 60;

      final now = DateTime.now();
      final unlockTime = now.add(Duration(minutes: durationMinutes));
      final lockoutEndTimeMs = unlockTime.millisecondsSinceEpoch;

      await prefs.setInt(keyLockoutEndTime, lockoutEndTimeMs);

      final nextLevel =
      (lockoutLevel + 1).clamp(0, lockoutDurationsMinutes.length - 1);
      await prefs.setInt(keyLockoutLevel, nextLevel);
      lockoutLevel = nextLevel;

      unlockDateTime = unlockTime;

      if (durationMinutes >= 1440) {
        isPermanentlyBlocked24h = true;
        if (!mounted) return;

        await LoadingDialog.show(
          context,
          title: 'Hemos Detectado Algunas Irregularidades',
          subtitle: 'Inténtelo después de ${_formatUnlockDate(unlockTime)}',
          autoDismiss: true,
          duration: const Duration(seconds: 5),
          customIcon: const Icon(
            Icons.block_rounded,
            color: Color(0xFFE53935),
            size: 56,
          ),
        );
      }

      _startLockoutTimer(durationSeconds);
    }
  }

  // Formateo del tiempo restante de bloqueo para la interfaz
  String _formatTimer(int seconds) {
    final hours = (seconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final remainingSecs = (seconds % 60).toString().padLeft(2, '0');

    if (seconds >= 3600) {
      return '$hours:$minutes:$remainingSecs';
    }
    return '$minutes:$remainingSecs';
  }

  // Ejecucion del proceso de autenticacion de usuario
  Future<void> _handleLogin() async {
    if (remainingSeconds > 0) return;

    if (!acceptPrivacy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes aceptar la Política de Privacidad.'),
        ),
      );
      return;
    }

    final email = emailController.text.trim();
    final password = passwordController.text;
    final selectedRole = _roles[_tabController.index];

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor completa todos los campos.'),
        ),
      );
      return;
    }

    // Validacion del formato de correo electronico requerido
    if (!email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El correo debe incluir la arroba, ejemplo: ejemplo@happiley.com.'),
        ),
      );
      return;
    }

    LoadingDialog.show(
      context,
      title: 'Iniciando Sesión',
      subtitle: 'Validando credenciales...',
      autoDismiss: false,
      customIcon: const SizedBox(
        width: 40,
        height: 40,
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5548F5)),
          strokeWidth: 3.5,
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 1000));

    final user = await _userService.loginUser(
      email: email,
      password: password,
      selectedRole: selectedRole,
    );

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (user != null) {
      await _resetFullSecurityPolicy();
      await _saveUserDataPreference(email);

      if (!mounted) return;

      await LoadingDialog.show(
        context,
        title: '¡Inicio de Sesión Exitoso!',
        subtitle: 'Bienvenido de nuevo a Happiley',
        autoDismiss: true,
        duration: const Duration(seconds: 5),
        customIcon: const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF4CAF50),
          size: 56,
        ),
      );

      if (!mounted) return;

      await SessionManager.saveSession(user.code);

      if (!mounted) return;

      if (widget.onLoginSuccess != null) {
        widget.onLoginSuccess!(user.code);
      } else if (Navigator.canPop(context)) {
        Navigator.pop(context, user.code);
      }
    } else {
      if (!mounted) return;

      await LoadingDialog.show(
        context,
        title: 'Datos No Válidos',
        subtitle: 'Contraseña incorrecta o correo no registrado.',
        autoDismiss: true,
        duration: const Duration(seconds: 5),
        customIcon: const Icon(
          Icons.cancel_rounded,
          color: Color(0xFFE53935),
          size: 56,
        ),
      );

      if (!mounted) return;

      await _handleFailedAttemptAfterDialog();
    }
  }

  @override
  void dispose() {
    lockoutTimer?.cancel();
    emailController.dispose();
    passwordController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // Construccion de la interfaz grafica de autenticacion
  @override
  Widget build(BuildContext context) {
    final bool isLocked = remainingSeconds > 0;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF5548F5),
          elevation: 0,
          toolbarHeight: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Color(0xFF5548F5),
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
        ),
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 25),

                    // Boton de retroceso condicional de la barra superior
                    if (Navigator.canPop(context))
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Color(0xFF20242B),
                            size: 24,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFF4F6FB),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 15),

                    // Logo de Happiley principal de la cabecera institucional
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'lib/assets/images/happiley_logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Titulo corporativo de la marca
                    const Text(
                      'Happiley',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5548F5),
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Subtitulo descriptivo del proposito comercial
                    const Text(
                      'Tu destino para lo mejor en tecnología',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF718096),
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Selector de pestañas de roles de usuario autorizados
                    Container(
                      height: 44,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F6FB),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFFE1E6F0),
                        ),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        dividerColor: Colors.transparent,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: const Color(0xFF5548F5),
                          borderRadius: BorderRadius.circular(21),
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: const Color(0xFF53647A),
                        labelStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        tabs: const [
                          Tab(text: 'Visitante'),
                          Tab(text: 'Vendedor'),
                          Tab(text: 'Admin'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 26),

                    // Etiqueta de campo para el correo electronico
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Correo Electrónico',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 7),

                    // Campo de texto editable para el correo electronico del usuario
                    TextField(
                      controller: emailController,
                      enabled: !isLocked,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'ejemplo@happiley.com',
                        hintStyle: const TextStyle(
                          color: Color(0xFF718096),
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.mail_outline,
                          color: Color(0xFF60748C),
                          size: 21,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 15,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(11),
                          borderSide: const BorderSide(
                            color: Color(0xFFDDE3ED),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(11),
                          borderSide: const BorderSide(
                            color: Color(0xFFDDE3ED),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(11),
                          borderSide: const BorderSide(
                            color: Color(0xFF5548F5),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 17),

                    // Etiqueta de campo para la contraseña de acceso
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Contraseña',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 7),

                    // Campo de texto protegido para la contraseña del sistema
                    TextField(
                      controller: passwordController,
                      enabled: !isLocked,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        hintText: '••••••••••••',
                        hintStyle: const TextStyle(
                          color: Color(0xFF718096),
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: Color(0xFF60748C),
                          size: 21,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: const Color(0xFF60748C),
                            size: 21,
                          ),
                          onPressed: isLocked
                              ? null
                              : () {
                            setState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 15,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(11),
                          borderSide: const BorderSide(
                            color: Color(0xFFDDE3ED),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(11),
                          borderSide: const BorderSide(
                            color: Color(0xFFDDE3ED),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(11),
                          borderSide: const BorderSide(
                            color: Color(0xFF5548F5),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 13),

                    // Casilla de verificacion para aceptar la politica de privacidad
                    _buildCheckRow(
                      value: acceptPrivacy,
                      text: 'Acepto la ',
                      linkText: 'Política de Privacidad',
                      onChanged: isLocked
                          ? (v) {}
                          : (value) {
                        setState(() {
                          acceptPrivacy = value ?? false;
                        });
                      },
                    ),

                    // Casilla de verificacion para recordar los datos de usuario
                    _buildCheckRow(
                      value: rememberData,
                      text: 'Recordar mis datos',
                      onChanged: isLocked
                          ? (v) {}
                          : (value) {
                        setState(() {
                          rememberData = value ?? false;
                        });
                      },
                    ),

                    const SizedBox(height: 17),

                    // Boton principal de envio para iniciar sesion en el sistema
                    SizedBox(
                      width: double.infinity,
                      height: 49,
                      child: ElevatedButton(
                        onPressed: isLocked ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5548F5),
                          disabledBackgroundColor: Colors.grey.shade300,
                          foregroundColor: Colors.white,
                          elevation: 5,
                          shadowColor: const Color(0x445548F5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Iniciar Sesión',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 10),
                            Icon(
                              Icons.arrow_forward,
                              size: 19,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Enlace interactivo para la recuperacion de credenciales olvidadas
                    TextButton(
                      onPressed: () {},
                      child: const Text(
                        '¿Olvidaste tu contraseña?',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Divisor estetico central con etiqueta textual divisoria
                    Row(
                      children: [
                        const Expanded(
                          child: Divider(
                            color: Color(0xFFE3E7EF),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 13),
                          child: Text(
                            'o',
                            style: TextStyle(
                              color: Colors.indigo.shade400,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Divider(
                            color: Color(0xFFE3E7EF),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Contenedor de botones para autenticacion mediante redes sociales
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icono de cierre para autenticacion externa alternativa
                        _buildSocialButton(
                          child: const Icon(
                            Icons.close,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 15),
                        // Icono de Facebook para inicio de sesion social
                        _buildSocialButton(
                          child: const Text(
                            'f',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        // Icono de Apple para inicio de sesion institucional
                        _buildSocialButton(
                          child: const Icon(
                            Icons.apple,
                            size: 21,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Bloque de navegacion secundaria hacia el registro de cuentas
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '¿No tienes cuenta? ',
                          style: TextStyle(
                            color: Color(0xFF657080),
                            fontSize: 12,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {},
                          child: const Text(
                            'Regístrate',
                            style: TextStyle(
                              color: Color(0xFF5548F5),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 25),
                  ],
                ),
              ),

              // Superposicion del contador visual de bloqueo de seguridad temporal
              if (isLocked)
                Positioned(
                  top: 15,
                  right: 15,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD32F2F).withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.access_time_filled,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatTimer(remainingSeconds),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Construccion de la fila de casillas de verificacion secundarias
  Widget _buildCheckRow({
    required bool value,
    required String text,
    String? linkText,
    required ValueChanged<bool?> onChanged,
  }) {
    return SizedBox(
      height: 35,
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF5548F5),
            side: const BorderSide(
              color: Color(0xFFD5DDEA),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: Color(0xFF20242B),
                  fontSize: 12,
                ),
                children: [
                  TextSpan(text: text),
                  if (linkText != null)
                    TextSpan(
                      text: linkText,
                      style: const TextStyle(
                        color: Color(0xFF5548F5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Construccion de los botones de autenticacion con redes sociales
  Widget _buildSocialButton({
    required Widget child,
  }) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: const Color(0xFFDCE3EE),
        ),
      ),
      child: Center(
        child: child,
      ),
    );
  }
}