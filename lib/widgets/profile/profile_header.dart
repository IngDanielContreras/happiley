import 'package:flutter/material.dart';
import '../../models/user.dart';

class ProfileHeader extends StatelessWidget {
  final User user;
  final VoidCallback onPickImage;
  final VoidCallback onLogout;

  const ProfileHeader({
    super.key,
    required this.user,
    required this.onPickImage,
    required this.onLogout,
  });

  // Obtencion de primer nombre y primer apellido
  String _getFormattedName(String firstName, String lastName) {
    final first = firstName.trim().split(' ').first;
    final last = lastName.trim().split(' ').first;
    return '$first $last';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Informacion de nombre y fechas
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _getFormattedName(user.firstName, user.lastName),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Boton de cerrar sesion
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFFF6E6E),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text(
                      'Salir',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Nacimiento: ${user.birthDate}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
              Text(
                'Ultimo acceso: ${user.lastAccessDate}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        // Imagen de usuario, identificador de rol y boton de carga
        Column(
          children: [
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage:
                  user.image != null ? AssetImage(user.image!) : null,
                  child: user.image == null
                      ? const Icon(
                    Icons.person,
                    size: 40,
                    color: Colors.white,
                  )
                      : null,
                ),
                // Vista ovalada del rol
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D2DA8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    user.role,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Boton rectangular de carga de foto
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5548F5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: onPickImage,
              icon: const Icon(Icons.camera_alt, size: 14),
              label: const Text(
                'Cargar Foto',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ],
    );
  }
}