import 'package:flutter/material.dart';
import '../services/music_manager.dart';

class AppSettings extends StatelessWidget {
  const AppSettings({super.key});

  // Despliegue del cuadro de dialogo modal de opciones
  static Future<void> showOptionsDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Padding(
            padding: EdgeInsets.all(20.0),
            child: AppSettings(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final musicManager = MusicManager();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado del menu de opciones con boton de cierre
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Opciones',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF101522),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const Divider(),
        const SizedBox(height: 10),
        // Etiqueta de la seccion del control de volumen
        const Text(
          'Volumen de música',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D2DA8),
          ),
        ),
        const SizedBox(height: 8),
        // Escucha reactiva del estado del volumen del reproductor de audio
        ValueListenableBuilder<double>(
          valueListenable: musicManager.volumeNotifier,
          builder: (context, volume, child) {
            final percentage = (volume * 100).round();
            final isMuted = volume == 0.0;

            return Column(
              children: [
                // Fila con el icono dinamico, la barra deslizante y el porcentaje visual
                Row(
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        isMuted ? Icons.music_off : Icons.music_note,
                        color: const Color(0xFF5548F5),
                        size: 26,
                      ),
                      onPressed: () {
                        if (isMuted) {
                          musicManager.setVolume(1.0);
                        } else {
                          musicManager.setVolume(0.0);
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Slider(
                        value: volume,
                        min: 0.0,
                        max: 1.0,
                        activeColor: const Color(0xFF5548F5),
                        inactiveColor: const Color(0xFFE0E3E8),
                        onChanged: (newVolume) {
                          musicManager.setVolume(newVolume);
                        },
                      ),
                    ),
                    SizedBox(
                      width: 45,
                      child: Text(
                        '$percentage%',
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF101522),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}