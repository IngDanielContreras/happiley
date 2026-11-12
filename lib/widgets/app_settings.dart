import 'package:flutter/material.dart';
import '../services/music_manager.dart';
import '../services/system_sound_manager.dart';
import '../services/theme_manager.dart';

// Componente modular de configuracion y opciones generales de la aplicacion
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

  // Seleccion dinamica del icono segun el porcentaje de volumen
  IconData _getSystemSoundIcon(int percentage) {
    if (percentage <= 0) {
      return Icons.volume_off;
    } else if (percentage < 34) {
      return Icons.volume_mute;
    } else if (percentage < 100) {
      return Icons.volume_down;
    } else {
      return Icons.volume_up;
    }
  }

  @override
  Widget build(BuildContext context) {
    final musicManager = MusicManager();
    final systemSoundManager = SystemSoundManager();
    final themeManager = ThemeManager();

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
            color: Color(0xFF5548F5),
          ),
        ),
        const SizedBox(height: 8),
        // Escucha reactiva del estado del volumen del reproductor de audio
        ValueListenableBuilder<double>(
          valueListenable: musicManager.volumeNotifier,
          builder: (context, volume, child) {
            final percentage = (volume * 100).round();
            final isMuted = percentage <= 0;
            final IconData currentMusicIcon =
            isMuted ? Icons.music_off : Icons.music_note;

            return Column(
              children: [
                // Fila con el icono dinamico, la barra deslizante y el porcentaje visual
                Row(
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, animation) {
                          return ScaleTransition(
                            scale: animation,
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child: Icon(
                          currentMusicIcon,
                          key: ValueKey<IconData>(currentMusicIcon),
                          color: const Color(0xFF5548F5),
                          size: 26,
                        ),
                      ),
                      onPressed: () {
                        musicManager.toggleMusic();
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Slider(
                        value: percentage.toDouble(),
                        min: 0.0,
                        max: 100.0,
                        divisions: 100,
                        activeColor: const Color(0xFF5548F5),
                        inactiveColor: const Color(0xFFE0E3E8),
                        onChanged: (newValue) {
                          musicManager.setVolume(newValue.round() / 100.0);
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
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 10),
        // Etiqueta de la seccion de sonidos del sistema
        const Text(
          'Sonidos del Sistema',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF5548F5),
          ),
        ),
        const SizedBox(height: 8),
        // Escucha reactiva del porcentaje de volumen de los sonidos del sistema
        ValueListenableBuilder<int>(
          valueListenable: systemSoundManager.volumePercentNotifier,
          builder: (context, percentage, child) {
            final IconData currentIcon = _getSystemSoundIcon(percentage);

            return Column(
              children: [
                // Fila con icono animado, barra deslizante continua y porcentaje
                Row(
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, animation) {
                          return ScaleTransition(
                            scale: animation,
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child: Icon(
                          currentIcon,
                          key: ValueKey<IconData>(currentIcon),
                          color: const Color(0xFF5548F5),
                          size: 26,
                        ),
                      ),
                      onPressed: () {
                        systemSoundManager.toggleMute();
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Slider(
                        value: percentage.toDouble(),
                        min: 0.0,
                        max: 100.0,
                        divisions: 100,
                        activeColor: const Color(0xFF5548F5),
                        inactiveColor: const Color(0xFFE0E3E8),
                        onChanged: (newValue) {
                          systemSoundManager.setVolumePercent(newValue.round());
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
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 10),
        // Etiqueta y boton para cambiar el tema de la aplicacion (Luna / Sol)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Tema de la aplicación',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5548F5),
              ),
            ),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: themeManager.themeModeNotifier,
              builder: (context, currentMode, child) {
                final isDark = currentMode == ThemeMode.dark;

                return IconButton(
                  tooltip: isDark ? 'Cambiar a Modo Claro' : 'Cambiar a Modo Oscuro',
                  icon: Icon(
                    isDark ? Icons.light_mode : Icons.dark_mode,
                    color: const Color(0xFF5548F5),
                    size: 28,
                  ),
                  onPressed: () {
                    themeManager.toggleTheme();
                  },
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}