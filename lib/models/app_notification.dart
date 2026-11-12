import 'package:flutter/material.dart';

// Tipos de eventos registrados en el sistema de notificaciones
enum AppNotificationType {
  welcome,
  loginSuccess,
  purchaseSuccess,
  purchaseFailed,
  publishSuccess,
  publishFailed,
}

// Modelo de datos representativo de cada notificacion
class AppNotification {
  final int? id;
  final String title;
  final String subtitle;
  final AppNotificationType type;
  final DateTime createdAt;
  final bool isRead;
  final String? userCode;
  final String? referenceId;

  const AppNotification({
    this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.userCode,
    this.referenceId,
  });

  // Copia inmutable con actualizacion selectiva de atributos
  AppNotification copyWith({
    int? id,
    String? title,
    String? subtitle,
    AppNotificationType? type,
    DateTime? createdAt,
    bool? isRead,
    String? userCode,
    String? referenceId,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      userCode: userCode ?? this.userCode,
      referenceId: referenceId ?? this.referenceId,
    );
  }

  // Seleccion del icono vectorial segun la categoria del evento
  IconData get iconData {
    switch (type) {
      case AppNotificationType.welcome:
        return Icons.waving_hand_rounded;
      case AppNotificationType.loginSuccess:
        return Icons.verified_user_rounded;
      case AppNotificationType.purchaseSuccess:
        return Icons.shopping_bag_rounded;
      case AppNotificationType.purchaseFailed:
        return Icons.error_outline_rounded;
      case AppNotificationType.publishSuccess:
        return Icons.inventory_rounded;
      case AppNotificationType.publishFailed:
        return Icons.report_problem_rounded;
    }
  }

  // Asignacion del color distintivo asociado al tipo de notificacion
  Color get accentColor {
    switch (type) {
      case AppNotificationType.welcome:
        return const Color(0xFF5548F5);
      case AppNotificationType.loginSuccess:
        return const Color(0xFF2E7D32);
      case AppNotificationType.purchaseSuccess:
        return const Color(0xFF1565C0);
      case AppNotificationType.purchaseFailed:
        return const Color(0xFFC62828);
      case AppNotificationType.publishSuccess:
        return const Color(0xFF00838F);
      case AppNotificationType.publishFailed:
        return const Color(0xFFD84315);
    }
  }

  // Serializacion del objeto hacia mapa relacional para SQLite
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'subtitle': subtitle,
      'type': type.name,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead ? 1 : 0,
      'user_code': userCode,
      'reference_id': referenceId,
    };
  }

  // Reconstruccion de la instancia desde un registro de base de datos
  factory AppNotification.fromMap(Map<String, dynamic> map) {
    final rawType = map['type'] as String? ?? AppNotificationType.welcome.name;
    final parsedType = AppNotificationType.values.firstWhere(
          (e) => e.name == rawType,
      orElse: () => AppNotificationType.welcome,
    );

    return AppNotification(
      id: map['id'] as int?,
      title: map['title'] as String? ?? '',
      subtitle: map['subtitle'] as String? ?? '',
      type: parsedType,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      isRead: (map['is_read'] as int? ?? 0) == 1,
      userCode: map['user_code'] as String?,
      referenceId: map['reference_id'] as String?,
    );
  }
}