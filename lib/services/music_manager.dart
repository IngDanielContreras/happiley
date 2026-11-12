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
  final ValueNotifier<double> volumeNotifier = ValueNotifier<double>(0.0);
  bool _isInitialized = false;
  bool _isToggling = false;
  bool _wasPlayingBeforePause = false;

  // Ruta física del archivo de audio en los assets del proyecto
  static const String _audioAssetPath =
      'lib/assets/music/toned_background_music.mp3';

  // Gestion del ciclo de vida de la aplicacion para pausar y reanudar el audio
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      if (isPlayingNotifier.value) {
        _wasPlayingBeforePause = true;
        _audioPlayer.pause();
      } else {
        _wasPlayingBeforePause = false;
      }
    } else if (state == AppLifecycleState.detached) {
      _wasPlayingBeforePause = false;
      _audioPlayer.stop();
      isPlayingNotifier.value = false;
      _isInitialized = false;
    } else if (state == AppLifecycleState.resumed) {
      if (_wasPlayingBeforePause && volumeNotifier.value > 0) {
        _audioPlayer.resume();
      }
    }
  }

  // Ajuste en tiempo real del volumen del reproductor de audio
  Future<void> setVolume(double volume) async {
    final clampedVolume = volume.clamp(0.0, 1.0);
    volumeNotifier.value = clampedVolume;
    await _audioPlayer.setVolume(clampedVolume);

    if (clampedVolume > 0 && !isPlayingNotifier.value) {
      await _startOrResume();
    } else if (clampedVolume == 0 && isPlayingNotifier.value) {
      await _audioPlayer.pause();
      isPlayingNotifier.value = false;
    }
  }

  // Inicio de la reproducción o reanudación del reproductor
  Future<void> _startOrResume() async {
    try {
      if (!_isInitialized) {
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
        await _audioPlayer.resume();
      }
      isPlayingNotifier.value = true;
    } catch (e) {
      debugPrint('Error al activar la música de fondo: $e');
      isPlayingNotifier.value = false;
      _isInitialized = false;
    }
  }

  // Gestión de reproducción, pausa e inicialización en bucle
  Future<void> toggleMusic() async {
    if (_isToggling) return;

    _isToggling = true;

    try {
      if (isPlayingNotifier.value) {
        // Pausa del audio para liberar recursos sin perder la posición
        await _audioPlayer.pause();
        await setVolume(0.0);
        isPlayingNotifier.value = false;
      } else {
        final targetVolume = volumeNotifier.value > 0 ? volumeNotifier.value : 1.0;
        await setVolume(targetVolume);
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