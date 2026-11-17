import 'dart:async';
import 'package:flutter/material.dart';
import '../services/system_sound_manager.dart';

// Controlador para actualizar el estado de carga a resultado dentro del mismo dialogo
class LoadingDialogController {
  Future<void> Function({
  required String title,
  required String subtitle,
  required bool isSuccess,
  Widget? customIcon,
  SystemSoundType? customSoundType,
  Duration duration,
  bool autoDismiss,
  })? _onShowResult;

  _PendingDialogResult? _pendingResult;

  void _attach(
      Future<void> Function({
      required String title,
      required String subtitle,
      required bool isSuccess,
      Widget? customIcon,
      SystemSoundType? customSoundType,
      Duration duration,
      bool autoDismiss,
      }) callback,
      ) {
    _onShowResult = callback;
    final _PendingDialogResult? pending = _pendingResult;
    if (pending != null) {
      _pendingResult = null;
      callback(
        title: pending.title,
        subtitle: pending.subtitle,
        isSuccess: pending.isSuccess,
        customIcon: pending.customIcon,
        customSoundType: pending.customSoundType,
        duration: pending.duration,
        autoDismiss: pending.autoDismiss,
      ).then((_) {
        if (!pending.completer.isCompleted) {
          pending.completer.complete();
        }
      });
    }
  }

  void _detach() {
    _onShowResult = null;
  }

  // Transiciona el icono interior hacia el resultado animado de exito o error
  Future<void> showResult({
    required String title,
    required String subtitle,
    required bool isSuccess,
    Widget? customIcon,
    SystemSoundType? customSoundType,
    Duration duration = const Duration(seconds: 4),
    bool autoDismiss = true,
  }) {
    final callback = _onShowResult;
    if (callback != null) {
      return callback(
        title: title,
        subtitle: subtitle,
        isSuccess: isSuccess,
        customIcon: customIcon,
        customSoundType: customSoundType,
        duration: duration,
        autoDismiss: autoDismiss,
      );
    }

    final Completer<void> completer = Completer<void>();
    _pendingResult = _PendingDialogResult(
      title: title,
      subtitle: subtitle,
      isSuccess: isSuccess,
      customIcon: customIcon,
      customSoundType: customSoundType,
      duration: duration,
      autoDismiss: autoDismiss,
      completer: completer,
    );
    return completer.future;
  }
}

class _PendingDialogResult {
  final String title;
  final String subtitle;
  final bool isSuccess;
  final Widget? customIcon;
  final SystemSoundType? customSoundType;
  final Duration duration;
  final bool autoDismiss;
  final Completer<void> completer;

  const _PendingDialogResult({
    required this.title,
    required this.subtitle,
    required this.isSuccess,
    required this.customIcon,
    required this.customSoundType,
    required this.duration,
    required this.autoDismiss,
    required this.completer,
  });
}

class LoadingDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final Widget? customIcon;
  final Duration duration;
  final bool autoDismiss;
  final bool playOpenSound;
  final SystemSoundType? customSoundType;
  final LoadingDialogController? controller;

  const LoadingDialog({
    super.key,
    required this.title,
    required this.subtitle,
    this.customIcon,
    this.duration = const Duration(seconds: 5),
    this.autoDismiss = false,
    this.playOpenSound = true,
    this.customSoundType,
    this.controller,
  });

  static Future<void> show(
      BuildContext context, {
        required String title,
        required String subtitle,
        Widget? customIcon,
        Duration duration = const Duration(seconds: 5),
        bool autoDismiss = false,
        bool playOpenSound = true,
        SystemSoundType? customSoundType,
        LoadingDialogController? controller,
      }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (BuildContext context) {
        return PopScope<Object?>(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
          },
          child: LoadingDialog(
            title: title,
            subtitle: subtitle,
            customIcon: customIcon,
            duration: duration,
            autoDismiss: autoDismiss,
            playOpenSound: playOpenSound,
            customSoundType: customSoundType,
            controller: controller,
          ),
        );
      },
    );
  }

  @override
  State<LoadingDialog> createState() => _LoadingDialogState();
}

class _LoadingDialogState extends State<LoadingDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _scaleAnimation;
  Timer? _timer;
  Completer<void>? _resultCompleter;

  late String _currentTitle;
  late String _currentSubtitle;
  Widget? _currentCustomIcon;

  @override
  void initState() {
    super.initState();

    _currentTitle = widget.title;
    _currentSubtitle = widget.subtitle;
    _currentCustomIcon = widget.customIcon;

    final bool isCustom = _currentCustomIcon != null;

    if (isCustom) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      )..forward();

      _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.elasticOut,
        ),
      );
    } else {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
      )..repeat(reverse: true);

      _scaleAnimation = Tween<double>(
        begin: 0.95,
        end: 1.05,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeInOut,
        ),
      );
    }

    _playInitialSound();

    if (widget.autoDismiss) {
      _scheduleAutoDismiss(widget.duration);
    }

    widget.controller?._attach(_handleShowResult);
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _timer?.cancel();
    if (_resultCompleter != null && !_resultCompleter!.isCompleted) {
      _resultCompleter!.complete();
    }
    _controller.dispose();
    super.dispose();
  }

  // Reproduccion sincronizada del sonido inicial segun el estado del dialogo
  void _playInitialSound() {
    final soundManager = SystemSoundManager();

    if (widget.customSoundType != null) {
      soundManager.playSound(widget.customSoundType!);
      return;
    }

    final Widget? iconWidget = _currentCustomIcon;
    if (iconWidget is Icon) {
      final IconData? iconData = iconWidget.icon;
      if (iconData == Icons.check_circle_rounded ||
          iconData == Icons.check_circle ||
          iconData == Icons.check) {
        soundManager.playSuccess();
        return;
      } else if (iconData == Icons.cancel_rounded ||
          iconData == Icons.cancel ||
          iconData == Icons.error_rounded ||
          iconData == Icons.error ||
          iconData == Icons.close_rounded ||
          iconData == Icons.block_rounded ||
          iconData == Icons.remove_shopping_cart_rounded) {
        soundManager.playError();
        return;
      } else if (iconData == Icons.warning_amber_rounded ||
          iconData == Icons.warning_rounded ||
          iconData == Icons.warning) {
        soundManager.playAlert();
        return;
      }
    }

    if (widget.playOpenSound) {
      soundManager.playDialogOpen();
    }
  }

  // Programacion del cierre automatico tras cumplirse la duracion definida
  void _scheduleAutoDismiss(Duration duration) {
    _timer?.cancel();
    _timer = Timer(duration, () {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      if (_resultCompleter != null && !_resultCompleter!.isCompleted) {
        _resultCompleter!.complete();
      }
    });
  }

  // Actualizacion exclusiva del icono interior hacia el estado de resultado
  Future<void> _handleShowResult({
    required String title,
    required String subtitle,
    required bool isSuccess,
    Widget? customIcon,
    SystemSoundType? customSoundType,
    Duration duration = const Duration(seconds: 4),
    bool autoDismiss = true,
  }) {
    if (!mounted) return Future<void>.value();

    final Widget resolvedIcon = customIcon ??
        Icon(
          isSuccess ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: isSuccess ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
          size: 56,
        );

    final SystemSoundType resolvedSound = customSoundType ??
        (isSuccess ? SystemSoundType.success : SystemSoundType.error);

    _controller.stop();
    _controller.duration = const Duration(milliseconds: 600);
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );

    setState(() {
      _currentTitle = title;
      _currentSubtitle = subtitle;
      _currentCustomIcon = resolvedIcon;
    });

    _controller.forward(from: 0.0);
    SystemSoundManager().playSound(resolvedSound);

    if (autoDismiss) {
      final Completer<void> completer = Completer<void>();
      _resultCompleter = completer;
      _scheduleAutoDismiss(duration);
      return completer.future;
    }

    return Future<void>.value();
  }

  Widget _buildAnimatedLogo() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double progress = _controller.value;
        return Container(
          // Tamano original de 80x80 para el logo de Happiley
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5548F5).withValues(
                  alpha: 0.1 + progress * 0.2,
                ),
                spreadRadius: 2 + progress * 4,
                blurRadius: 8 + progress * 8,
              ),
            ],
          ),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.asset(
                'lib/assets/images/happiley_logo.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const ColoredBox(
                    color: Color(0xFFF0EEFF),
                    child: Icon(
                      Icons.hourglass_top_rounded,
                      color: Color(0xFF5548F5),
                      size: 42,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Widget iconToDisplay = _currentCustomIcon != null
        ? ScaleTransition(
      scale: _scaleAnimation,
      child: _currentCustomIcon,
    )
        : _buildAnimatedLogo();

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconToDisplay,
          const SizedBox(height: 18),
          Text(
            _currentTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF20242B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currentSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFFB3BACB) : const Color(0xFF718096),
            ),
          ),
        ],
      ),
    );
  }
}