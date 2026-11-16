import 'package:flutter/material.dart';
import '../services/system_sound_manager.dart';

class AlertMessage {
  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Aceptar',
    String cancelText = 'Cancelar',
    bool isConfirmDefault = true,
    bool playConfirmSound = true,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  }) {

    // Reproduccion del sonido de presentacion de alerta
    SystemSoundManager().playDialogOpen();

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        final Color dialogBackground =
        isDark ? const Color(0xFF252834) : const Color(0xFFE6E8EF);
        final Color titleColor =
        isDark ? const Color(0xFFF1F3F9) : const Color(0xFF181B24);
        final Color messageColor =
        isDark ? const Color(0xFFC7CDDC) : const Color(0xFF373D4D);
        final Color secondaryBg =
        isDark ? const Color(0xFF363B4B) : const Color(0xFFCFD4E0);
        final Color secondaryFg =
        isDark ? const Color(0xFFE2E6F0) : const Color(0xFF252A37);

        return PopScope<Object?>(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
          },
          child: AlertDialog(
            backgroundColor: dialogBackground,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),

            // Titulo de la alerta
            title: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: titleColor,
              ),
            ),

            // Contenido textual de la alerta
            content: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: messageColor,
              ),
            ),

            // Acciones y botones de la alerta
            actions: [
              // Boton aceptar
              ElevatedButton(
                onPressed: () {
                  if (playConfirmSound) {
                    SystemSoundManager().playAcceptYes();
                  }
                  Navigator.of(context).pop(true);
                  if (onConfirm != null) {
                    onConfirm();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isConfirmDefault
                      ? const Color(0xFF5548F5)
                      : secondaryBg,
                  foregroundColor: isConfirmDefault
                      ? Colors.white
                      : secondaryFg,
                  elevation: isConfirmDefault ? 2 : 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  confirmText,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Boton cancelar
              ElevatedButton(
                onPressed: () {
                  SystemSoundManager().playDeniedNo();
                  Navigator.of(context).pop(false);
                  if (onCancel != null) {
                    onCancel();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isConfirmDefault
                      ? secondaryBg
                      : const Color(0xFF5548F5),
                  foregroundColor: isConfirmDefault
                      ? secondaryFg
                      : Colors.white,
                  elevation: isConfirmDefault ? 0 : 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  cancelText,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}