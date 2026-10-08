import 'package:flutter/material.dart';
import '../database/user_service.dart';

class LoginScreen extends StatefulWidget {
  final Function(int userId)? onLoginSuccess;

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // Procesamiento del inicio de sesion
  Future<void> _handleLogin() async {
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

    // Autenticacion del usuario en la base de datos
    final user = await _userService.loginUser(
      email: email,
      password: password,
      selectedRole: selectedRole,
    );

    if (user != null && mounted) {
      // Notificacion de inicio de sesion exitoso
      if (widget.onLoginSuccess != null) {
        widget.onLoginSuccess!(user.id);
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contraseña incorrecta o datos no válidos.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 10),

              // Botón Volver
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

              // Logo de Happiley
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
                  borderRadius: BorderRadius.circular(24), // Recorta la imagen para que coincida con el contenedor
                  child: Image.asset(
                    'lib/assets/images/happiley_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Nombre de la aplicación
              const Text(
                'Happiley',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5548F5),
                ),
              ),

              const SizedBox(height: 4),

              const Text(
                'Tu destino para lo mejor en tecnología',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF718096),
                ),
              ),

              const SizedBox(height: 36),

              // Selector de roles con TabController
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

              // Correo
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

              TextField(
                controller: emailController,
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

              // Contraseña
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

              TextField(
                controller: passwordController,
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
                    onPressed: () {
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

              // Política de privacidad
              _buildCheckRow(
                value: acceptPrivacy,
                text: 'Acepto la ',
                linkText: 'Política de Privacidad',
                onChanged: (value) {
                  setState(() {
                    acceptPrivacy = value ?? false;
                  });
                },
              ),

              // Recordar datos
              _buildCheckRow(
                value: rememberData,
                text: 'Recordar mis datos',
                onChanged: (value) {
                  setState(() {
                    rememberData = value ?? false;
                  });
                },
              ),

              const SizedBox(height: 17),

              // Botón iniciar sesión
              SizedBox(
                width: double.infinity,
                height: 49,
                child: ElevatedButton(
                  onPressed: _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5548F5),
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

              // Recuperar contraseña
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

              // Separador
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

              // Redes sociales
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSocialButton(
                    child: const Icon(
                      Icons.close,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 15),
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
                  _buildSocialButton(
                    child: const Icon(
                      Icons.apple,
                      size: 21,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Registro
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
      ),
    );
  }

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