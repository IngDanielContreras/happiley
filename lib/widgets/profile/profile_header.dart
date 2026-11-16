import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../screens/image_viewer_screen.dart';

class ProfileHeader extends StatelessWidget {
  final User user;

  const ProfileHeader({
    super.key,
    required this.user,
  });

  // Obtencion del nombre completo del usuario
  String _getFullName(String firstName, String lastName) {
    final cleanFirst = firstName.trim();
    final cleanLast = lastName.trim();
    return '$cleanFirst $cleanLast'.trim();
  }

  // Resolucion del proveedor de imagen para el avatar
  ImageProvider<Object>? _resolveAvatarImage(String? imagePath) {
    if (imagePath == null || imagePath.trim().isEmpty) {
      return null;
    }

    final String cleanPath = imagePath.trim();
    if (cleanPath.startsWith('lib/assets/') ||
        cleanPath.startsWith('assets/')) {
      return AssetImage(cleanPath);
    }

    final File file = File(cleanPath);
    if (file.existsSync()) {
      return FileImage(file);
    }

    return null;
  }

  // Apertura del visor existente al pulsar la fotografia de perfil
  void _openProfileImageViewer(BuildContext context) {
    final String? rawPath = user.image;
    if (rawPath == null || rawPath.trim().isEmpty) return;

    final String cleanPath = rawPath.trim();
    final bool isAsset = cleanPath.startsWith('lib/assets/') ||
        cleanPath.startsWith('assets/');

    if (!isAsset && !File(cleanPath).existsSync()) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageViewerScreen(imagePath: cleanPath),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ImageProvider<Object>? avatarImage = _resolveAvatarImage(user.image);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color subtitleColor =
    isDark ? Colors.grey.shade400 : Colors.grey.shade700;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Fotografia de perfil con identificador de rol
        GestureDetector(
          onTap: () => _openProfileImageViewer(context),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: avatarImage,
                child: avatarImage == null
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
        ),

        const SizedBox(width: 14),

        // Nombre completo, fecha de nacimiento y ultimo acceso
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getFullName(user.firstName, user.lastName),
                textAlign: TextAlign.left,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Nacimiento: ${user.birthDate}',
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: 12.5,
                  color: subtitleColor,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Último acceso: ${user.lastAccessDate}',
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: 12.5,
                  color: subtitleColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}