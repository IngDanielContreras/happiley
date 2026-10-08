import 'package:flutter/material.dart';
import '../models/user.dart';
import '../database/user_service.dart';
import '../widgets/profile/profile_header.dart';
import '../widgets/profile/universal_info_card.dart';
import '../widgets/profile/admin_attributes.dart';
import '../widgets/profile/role_options.dart';

class ProfileScreen extends StatefulWidget {
  final dynamic userCode;
  final VoidCallback? onLogout;

  const ProfileScreen({
    super.key,
    required this.userCode,
    this.onLogout,
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

  // Carga de la información del usuario desde la base de datos
  void _loadUserData() {
    setState(() {
      _userFuture = _userService.getUserById(widget.userCode);
    });
  }

  // Carga de nueva foto de perfil
  void _handleImagePick(User user) {

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF5548F5),
        foregroundColor: Colors.white,
        title: const Text(
          'Perfil de Usuario',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
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
                      if (widget.onLogout != null) {
                        widget.onLogout!();
                      }
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
                // Encabezado universal con foto y datos basicos
                ProfileHeader(
                  user: user,
                  onPickImage: () => _handleImagePick(user),
                  onLogout: widget.onLogout ?? () {},
                ),

                const Divider(height: 32),

                // Tarjeta de informacion universal
                UniversalInfoCard(user: user),

                // Atributos exclusivos para Administrador
                if (isAdmin) ...[
                  const Divider(height: 32),
                  AdminAttributes(user: user),
                ],

                const Divider(height: 32),

                // Opciones de navegacion por rol
                RoleOptions(user: user),
              ],
            ),
          );
        },
      ),
    );
  }
}