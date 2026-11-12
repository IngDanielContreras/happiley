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
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  }) {

    // Reproduccion del sonido de presentacion de alerta
    SystemSoundManager().playDialogOpen();

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope<Object?>(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
          },
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),

            // Titulo de la alerta
            title: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),

            // Contenido textual de la alerta
            content: Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF515A6A),
              ),
            ),

            // Acciones y botones de la alerta
            actions: [
              // Boton aceptar
              ElevatedButton(
                onPressed: () {
                  SystemSoundManager().playAcceptYes();
                  Navigator.of(context).pop(true);
                  if (onConfirm != null) {
                    onConfirm();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isConfirmDefault
                      ? const Color(0xFF5548F5)
                      : Colors.grey.shade200,
                  foregroundColor: isConfirmDefault
                      ? Colors.white
                      : Colors.grey.shade800,
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
                      ? Colors.grey.shade200
                      : const Color(0xFF5548F5),
                  foregroundColor: isConfirmDefault
                      ? Colors.grey.shade800
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