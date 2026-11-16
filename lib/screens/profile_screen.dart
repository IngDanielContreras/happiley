import 'package:flutter/material.dart';
import '../models/user.dart';
import '../database/user_service.dart';
import '../services/system_sound_manager.dart';
import '../widgets/profile/profile_header.dart';
import '../widgets/profile/universal_info_card.dart';
import '../widgets/profile/admin_attributes.dart';
import '../widgets/profile/role_options.dart';
import '../widgets/custom_app_bar.dart';
import 'account_info_screen.dart';

class ProfileScreen extends StatefulWidget {
  final dynamic userCode;
  final VoidCallback? onLogout;
  final VoidCallback? onPublishArticle;

  const ProfileScreen({
    super.key,
    required this.userCode,
    this.onLogout,
    this.onPublishArticle,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = UserService();
  late Future<User?> _userFuture;

  @override
  void initState() {
    super.initState();
    // Carga inicial con los datos del usuario
    _loadUserData();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recarga la informacion si el identificador cambia en la interfaz
    if (oldWidget.userCode != widget.userCode) {
      _loadUserData();
    }
  }

  // Carga de la informacion del usuario desde la base de datos
  void _loadUserData() {
    _userFuture = _userService.getUserById(widget.userCode);
  }

  // Apertura de la pantalla de informacion de cuenta y recarga al volver
  Future<void> _openAccountInfoScreen(User user) async {
    final bool? updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AccountInfoScreen(
          userCode: user.code,
        ),
      ),
    );

    if (updated == true && mounted) {
      setState(() {
        _loadUserData();
      });
    }
  }

  // Cuadro de dialogo para confirmar el cierre de sesion
  Future<void> _showLogoutDialog(BuildContext context) async {
    SystemSoundManager().playDialogOpen();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final bool isDark =
            Theme.of(dialogContext).brightness == Brightness.dark;
        final Color dialogBackground =
        isDark ? const Color(0xFF252834) : const Color(0xFFE6E8EF);
        final Color cancelBg =
        isDark ? const Color(0xFF363B4B) : const Color(0xFFCFD4E0);
        final Color cancelFg =
        isDark ? const Color(0xFFE2E6F0) : const Color(0xFF252A37);

        return AlertDialog(
          backgroundColor: dialogBackground,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Cerrar Sesión',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: const Text(
            '¿Está seguro de cerrar su sesión?',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: cancelBg,
                foregroundColor: cancelFg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                SystemSoundManager().playDeniedNo();
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text(
                'Cancelar',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                SystemSoundManager().playAcceptYes();
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Cerrar Sesión'),
            ),
          ],
        );
      },
    );

    // Si el usuario confirma, ejecuta el callback de salida
    if (confirm == true) {
      widget.onLogout?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Perfil de Usuario',
      ),
      body: FutureBuilder<User?>(
        future: _userFuture,
        builder: (context, snapshot) {
          // Indicador de carga
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF5548F5),
              ),
            );
          }

          // Manejo de error o usuario no encontrado
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Oops! Tenemos problemas para cargar\nla información del usuario (ID: ${widget.userCode}).\n|Inténtalo Más Tarde|.',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5548F5),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        _loadUserData();
                      });
                    },
                    child: const Text('Volver a intentar'),
                  ),
                ],
              ),
            );
          }

          final user = snapshot.data!;
          final isAdmin = user.role.toLowerCase().trim() == 'administrador' &&
              user.code.startsWith('AUR');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado universal con foto, nacimiento y ultimo acceso
                ProfileHeader(
                  user: user,
                ),

                const Divider(height: 32),

                // Tarjeta de informacion universal
                UniversalInfoCard(user: user),

                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openAccountInfoScreen(user),
                    icon: const Icon(
                      Icons.manage_accounts_outlined,
                      color: Color(0xFF5548F5),
                    ),
                    label: const Text(
                      'Ver Información de Cuenta',
                      style: TextStyle(
                        color: Color(0xFF5548F5),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFF5548F5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                // Atributos exclusivos para Administrador
                if (isAdmin) ...[
                  const Divider(height: 32),
                  AdminAttributes(user: user),
                ],

                const Divider(height: 32),

                // Opciones de navegacion por rol
                RoleOptions(
                  user: user,
                  onPublishArticle: widget.onPublishArticle,
                ),

                const SizedBox(height: 24),

                // Boton rectangular con bordes redondeados al final de la pantalla
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _showLogoutDialog(context),
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text(
                      'Cerrar Sesión',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}