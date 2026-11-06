import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MusicManager with WidgetsBindingObserver {
  // Instancia única (Singleton) para controlar el reproductor global
  static final MusicManager _instance = MusicManager._internal();
  factory MusicManager() => _instance;

  MusicManager._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  // Controladores del reproductor y estado visual del botón
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<double> volumeNotifier = ValueNotifier<double>(1.0);
  bool _isInitialized = false;
  bool _isToggling = false;
  bool _wasPlayingBeforePause = false;

  // Ruta física del archivo de audio en los assets del proyecto
  static const String _audioAssetPath =
      'lib/assets/music/musica_fondo_happiley.mp3';

  // Gestion del ciclo de vida de la aplicacion para pausar y reanudar el audio
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (isPlayingNotifier.value) {
        _wasPlayingBeforePause = true;
        _audioPlayer.pause();
      } else {
        _wasPlayingBeforePause = false;
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_wasPlayingBeforePause) {
        _audioPlayer.resume();
      }
    }
  }

  // Ajuste en tiempo real del volumen del reproductor de audio
  Future<void> setVolume(double volume) async {
    final clampedVolume = volume.clamp(0.0, 1.0);
    volumeNotifier.value = clampedVolume;
    await _audioPlayer.setVolume(clampedVolume);
  }

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
          await _audioPlayer.setVolume(volumeNotifier.value);
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
    WidgetsBinding.instance.removeObserver(this);
    await _audioPlayer.stop();
    await _audioPlayer.dispose();
    _isInitialized = false;
    isPlayingNotifier.value = false;
  }
}