import 'package:flutter/material.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';
import '../services/system_sound_manager.dart';

// Boton de barra superior con contador circular y panel desplegable
class NotificationBellButton extends StatefulWidget {
  const NotificationBellButton({super.key});

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  // Alternancia de apertura y cierre del panel de notificaciones
  void _togglePanel() {
    if (_isOpen) {
      _closePanel();
    } else {
      _openPanel();
    }
  }

  // Insercion del panel animado en la capa superior de la interfaz
  void _openPanel() {
    if (_isOpen) return;
    SystemSoundManager().playAcceptYes();

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return _NotificationsOverlayWrapper(
          layerLink: _layerLink,
          onDismissed: _removeOverlay,
        );
      },
    );

    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
    setState(() {
      _isOpen = true;
    });
  }

  // Solicitud de reconstruccion para iniciar cierre animado
  void _closePanel() {
    _overlayEntry?.markNeedsBuild();
  }

  // Liberacion de recursos de la capa superpuesta al finalizar cierre
  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() {
        _isOpen = false;
      });
    } else {
      _isOpen = false;
    }
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notificationService = NotificationService();

    return CompositedTransformTarget(
      link: _layerLink,
      child: ValueListenableBuilder<int>(
        valueListenable: notificationService.unreadCountNotifier,
        builder: (context, unreadCount, _) {
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'Notificaciones',
                onPressed: _togglePanel,
                icon: Icon(
                  _isOpen
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  color: Colors.white,
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: IgnorePointer(
                    child: AnimatedScale(
                      scale: unreadCount > 0 ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutBack,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935),
                          shape: unreadCount < 10
                              ? BoxShape.circle
                              : BoxShape.rectangle,
                          borderRadius: unreadCount < 10
                              ? null
                              : BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF5548F5),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// Contenedor animado del panel desplegable de notificaciones
class _NotificationsOverlayWrapper extends StatefulWidget {
  final LayerLink layerLink;
  final VoidCallback onDismissed;

  const _NotificationsOverlayWrapper({
    required this.layerLink,
    required this.onDismissed,
  });

  @override
  State<_NotificationsOverlayWrapper> createState() =>
      _NotificationsOverlayWrapperState();
}

class _NotificationsOverlayWrapperState
    extends State<_NotificationsOverlayWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _slideAnimation;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 200),
    );

    final curvedOpen = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(curvedOpen);
    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(curvedOpen);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.04),
      end: Offset.zero,
    ).animate(curvedOpen);

    _controller.forward().then((_) {
      if (mounted && !_isClosing) {
        NotificationService().markAllAsRead();
      }
    });
  }

  // Ejecucion de animacion inversa previa al cierre del panel
  Future<void> _animateAndClose() async {
    if (_isClosing) return;
    _isClosing = true;
    await _controller.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Formateo legible de fecha y hora de la notificacion
  String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final panelWidth = (screenWidth - 32).clamp(280.0, 380.0);
    final maxPanelHeight = (screenHeight * 0.58).clamp(260.0, 460.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _animateAndClose();
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _animateAndClose,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.22),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + kToolbarHeight + 4,
            right: 16,
            width: panelWidth,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  alignment: Alignment.topRight,
                  child: Material(
                    elevation: 14,
                    shadowColor: Colors.black38,
                    borderRadius: BorderRadius.circular(20),
                    color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                    child: Container(
                      constraints: BoxConstraints(maxHeight: maxPanelHeight),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? Colors.white12
                              : const Color(0xFFE1E5EB),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF5548F5)
                                  .withValues(alpha: isDark ? 0.22 : 0.08),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF5548F5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.notifications_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Notificaciones',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Cerrar panel',
                                  onPressed: _animateAndClose,
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 20,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          ),
                          Flexible(
                            child: ValueListenableBuilder<List<AppNotification>>(
                              valueListenable:
                              NotificationService().notificationsNotifier,
                              builder: (context, items, _) {
                                if (items.isEmpty) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 36,
                                      horizontal: 20,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.notifications_off_outlined,
                                          size: 40,
                                          color: Color(0xFF8C96A6),
                                        ),
                                        SizedBox(height: 10),
                                        Text(
                                          'No tienes notificaciones registradas.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF657080),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                return ListView.separated(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 10,
                                  ),
                                  shrinkWrap: true,
                                  itemCount: items.length,
                                  separatorBuilder: (_, __) =>
                                  const SizedBox(height: 6),
                                  itemBuilder: (context, index) {
                                    final item = items[index];
                                    return _NotificationTile(
                                      notification: item,
                                      formattedDate:
                                      _formatDateTime(item.createdAt),
                                      isDark: isDark,
                                      onDismiss: item.id != null &&
                                          item.type !=
                                              AppNotificationType.welcome
                                          ? () => NotificationService()
                                          .deleteNotification(item.id!)
                                          : null,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Tarjeta individual de presentacion de cada notificacion
class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final String formattedDate;
  final bool isDark;
  final VoidCallback? onDismiss;

  const _NotificationTile({
    required this.notification,
    required this.formattedDate,
    required this.isDark,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final accent = notification.accentColor;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: notification.isRead
            ? (isDark ? const Color(0xFF252536) : const Color(0xFFF8F9FC))
            : accent.withValues(alpha: isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: notification.isRead
              ? (isDark ? Colors.white10 : const Color(0xFFE6EAF0))
              : accent.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              notification.iconData,
              color: accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1A202C),
                        ),
                      ),
                    ),
                    if (!notification.isRead)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(left: 6),
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification.subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: isDark ? Colors.white70 : const Color(0xFF515A6A),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark
                            ? Colors.white54
                            : const Color(0xFF7B8494),
                      ),
                    ),
                    if (onDismiss != null)
                      GestureDetector(
                        onTap: onDismiss,
                        child: Text(
                          'Eliminar',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade400,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}