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

  // Formateo de fecha y hora del ultimo acceso en formato de 12 horas
  String _formatLastAccessDisplay(String rawValue) {
    final String trimmed = rawValue.trim();
    if (trimmed.isEmpty) return 'Primer acceso';

    String format12Hour(DateTime dt) {
      final DateTime localDt = dt.toLocal();
      final String day = localDt.day.toString().padLeft(2, '0');
      final String month = localDt.month.toString().padLeft(2, '0');
      final String year = localDt.year.toString().padLeft(4, '0');
      final int hour24 = localDt.hour;
      final int hour12 =
      hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
      final String minute = localDt.minute.toString().padLeft(2, '0');
      final String period = hour24 >= 12 ? 'P.M.' : 'A.M.';
      return '$day/$month/$year a las $hour12:$minute $period';
    }

    final DateTime? isoParsed = DateTime.tryParse(trimmed);
    if (isoParsed != null) {
      if (trimmed.contains(':') || trimmed.contains('T')) {
        return format12Hour(isoParsed);
      }
      final String day = isoParsed.day.toString().padLeft(2, '0');
      final String month = isoParsed.month.toString().padLeft(2, '0');
      final String year = isoParsed.year.toString().padLeft(4, '0');
      return '$day/$month/$year';
    }

    final RegExp dmyPattern = RegExp(
      r'^(\d{1,2})/(\d{1,2})/(\d{2,4})(?:(?:\s+a\s+las\s+|[ T]+)(\d{1,2}):(\d{2})(?::(\d{2}))?(?:\s*([AaPp]\.?[Mm]\.?))?)?$',
      caseSensitive: false,
    );
    final Match? match = dmyPattern.firstMatch(trimmed);
    if (match != null) {
      final int day = int.parse(match.group(1)!);
      final int month = int.parse(match.group(2)!);
      int year = int.parse(match.group(3)!);
      if (year < 100) {
        year += 2000;
      }

      if (match.group(4) == null) {
        final String d = day.toString().padLeft(2, '0');
        final String m = month.toString().padLeft(2, '0');
        final String y = year.toString().padLeft(4, '0');
        return '$d/$m/$y';
      }

      int hour = int.parse(match.group(4)!);
      final int minute = int.parse(match.group(5)!);
      final int second = match.group(6) != null ? int.parse(match.group(6)!) : 0;
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
        return format12Hour(candidate);
      }
    }

    return trimmed;
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
                'Último acceso: ${_formatLastAccessDisplay(user.lastAccessDate)}',
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