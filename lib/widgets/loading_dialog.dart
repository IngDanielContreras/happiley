import 'dart:async';
import 'package:flutter/material.dart';

class LoadingDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final Widget? customIcon;
  final Duration duration;
  final bool autoDismiss;

  const LoadingDialog({
    super.key,
    required this.title,
    required this.subtitle,
    this.customIcon,
    this.duration = const Duration(seconds: 5),
    this.autoDismiss = false,
  });

  static Future<void> show(
      BuildContext context, {
        required String title,
        required String subtitle,
        Widget? customIcon,
        Duration duration = const Duration(seconds: 5),
        bool autoDismiss = false,
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
  late final Animation<double> _scaleAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    final bool isCustom = widget.customIcon != null;

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

    if (widget.autoDismiss) {
      _timer = Timer(widget.duration, () {
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pop();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Widget _buildAnimatedLogo() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double progress = _controller.value;
        return Container(
          // Tamaño original de 80x80 para el logo de Happiley
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5548F5).withOpacity(0.1 + progress * 0.2),
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
    final Widget iconToDisplay = widget.customIcon != null
        ? ScaleTransition(
      scale: _scaleAnimation,
      child: widget.customIcon,
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
            widget.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF20242B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF718096),
            ),
          ),
        ],
      ),
    );
  }
}