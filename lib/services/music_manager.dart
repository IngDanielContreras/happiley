import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MusicManager {
  // Instancia única (Singleton) para controlar el reproductor global
  static final MusicManager _instance = MusicManager._internal();
  factory MusicManager() => _instance;
  MusicManager._internal();

  // Controladores del reproductor y estado visual del botón
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  bool _isInitialized = false;
  bool _isToggling = false;

  // Ruta física del archivo de audio en los assets del proyecto
  static const String _audioAssetPath =
      'lib/assets/music/musica_fondo_happiley.mp3';

  // Gestión de reproducción, pausa e inicialización en bucle
  Future<void> toggleMusic() async {
    if (_isToggling) return;

    _isToggling = true;

    try {
      if (isPlayingNotifier.value) {
        // Pausa del audio para liberar recursos sin perder la posición
        await _audioPlayer.pause();
        isPlayingNotifier.value = false;
      } else {
        if (!_isInitialized) {
          // Carga del archivo binario y configuración de repetición continua
          final audioData = await rootBundle.load(_audioAssetPath);

          final audioBytes = audioData.buffer.asUint8List(
            audioData.offsetInBytes,
            audioData.lengthInBytes,
          );

          await _audioPlayer.setReleaseMode(ReleaseMode.loop);
          await _audioPlayer.play(BytesSource(audioBytes));
          _isInitialized = true;
        } else {
          // Reanudación inmediata del sonido desde el segundo pausado
          await _audioPlayer.resume();
        }

        isPlayingNotifier.value = true;
      }
    } catch (e) {
      debugPrint('Error en la reproducción de la música de fondo: $e');
      isPlayingNotifier.value = false;
      _isInitialized = false;
    } finally {
      _isToggling = false;
    }
  }

  // Cierre y liberación completa de memoria del reproductor
  Future<void> stopAndDispose() async {
    await _audioPlayer.stop();
    await _audioPlayer.dispose();
    _isInitialized = false;
    isPlayingNotifier.value = false;
  }
}