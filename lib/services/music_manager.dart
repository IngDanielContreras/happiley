import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MusicManager with WidgetsBindingObserver {
  // Instancia unica (Singleton) para controlar el reproductor global
  static final MusicManager _instance = MusicManager._internal();
  factory MusicManager() => _instance;

  MusicManager._internal() {
    WidgetsBinding.instance.addObserver(this);
    _configureAudioContext();
  }

  // Controladores del reproductor y estado visual del boton
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<double> volumeNotifier = ValueNotifier<double>(0.0);
  bool _isInitialized = false;
  bool _isToggling = false;
  bool _wasPlayingBeforePause = false;

  int _activeDuckRequests = 0;
  double _currentDuckMultiplier = 1.0;
  Timer? _duckFadeTimer;
  static const double _duckedTargetMultiplier = 0.25;

  // Ruta fisica del archivo de audio en los assets del proyecto
  static const String _audioAssetPath =
      'lib/assets/music/toned_background_music.mp3';

  Future<void> _configureAudioContext() async {
    try {
      await _audioPlayer.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error al configurar contexto de musica de fondo: $e');
    }
  }

  double get _effectiveVolume =>
      (volumeNotifier.value * _currentDuckMultiplier).clamp(0.0, 1.0);

  void requestDuck() {
    _activeDuckRequests++;
    _animateDuckMultiplier(_duckedTargetMultiplier);
  }

  void releaseDuck() {
    if (_activeDuckRequests > 0) {
      _activeDuckRequests--;
    }
    if (_activeDuckRequests == 0) {
      _animateDuckMultiplier(1.0);
    }
  }

  void _animateDuckMultiplier(double targetMultiplier) {
    _duckFadeTimer?.cancel();
    const int steps = 8;
    const Duration stepDuration = Duration(milliseconds: 25);
    final double startMultiplier = _currentDuckMultiplier;
    final double delta = targetMultiplier - startMultiplier;

    if (delta.abs() < 0.001) {
      _currentDuckMultiplier = targetMultiplier;
      _applyEffectiveVolume();
      return;
    }

    int currentStep = 0;
    _duckFadeTimer = Timer.periodic(stepDuration, (timer) {
      currentStep++;
      if (currentStep >= steps) {
        _currentDuckMultiplier = targetMultiplier;
        _applyEffectiveVolume();
        timer.cancel();
      } else {
        _currentDuckMultiplier =
            startMultiplier + (delta * (currentStep / steps));
        _applyEffectiveVolume();
      }
    });
  }

  Future<void> _applyEffectiveVolume() async {
    if (!_isInitialized && !isPlayingNotifier.value) return;
    try {
      await _audioPlayer.setVolume(_effectiveVolume);
    } catch (e) {
      debugPrint('Error al aplicar volumen efectivo: $e');
    }
  }

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
    await _audioPlayer.setVolume(_effectiveVolume);

    if (clampedVolume > 0 && !isPlayingNotifier.value) {
      await _startOrResume();
    } else if (clampedVolume == 0 && isPlayingNotifier.value) {
      await _audioPlayer.pause();
      isPlayingNotifier.value = false;
    }
  }

  // Inicio de la reproduccion o reanudacion del reproductor
  Future<void> _startOrResume() async {
    try {
      if (!_isInitialized) {
        await _configureAudioContext();
        final audioData = await rootBundle.load(_audioAssetPath);
        final audioBytes = audioData.buffer.asUint8List(
          audioData.offsetInBytes,
          audioData.lengthInBytes,
        );

        await _audioPlayer.setReleaseMode(ReleaseMode.loop);
        await _audioPlayer.setVolume(_effectiveVolume);
        await _audioPlayer.play(BytesSource(audioBytes));
        _isInitialized = true;
      } else {
        await _audioPlayer.setVolume(_effectiveVolume);
        await _audioPlayer.resume();
      }
      isPlayingNotifier.value = true;
    } catch (e) {
      debugPrint('Error al activar la musica de fondo: $e');
      isPlayingNotifier.value = false;
      _isInitialized = false;
    }
  }

  // Gestion de reproduccion, pausa e inicializacion en bucle
  Future<void> toggleMusic() async {
    if (_isToggling) return;

    _isToggling = true;

    try {
      if (isPlayingNotifier.value) {
        // Pausa del audio para liberar recursos sin perder la posicion
        await _audioPlayer.pause();
        await setVolume(0.0);
        isPlayingNotifier.value = false;
      } else {
        final targetVolume = volumeNotifier.value > 0 ? volumeNotifier.value : 1.0;
        await setVolume(targetVolume);
      }
    } catch (e) {
      debugPrint('Error en la reproduccion de la musica de fondo: $e');
      isPlayingNotifier.value = false;
      _isInitialized = false;
    } finally {
      _isToggling = false;
    }
  }

  // Cierre y liberacion completa de memoria del reproductor
  Future<void> stopAndDispose() async {
    _duckFadeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    await _audioPlayer.stop();
    await _audioPlayer.dispose();
    _isInitialized = false;
    isPlayingNotifier.value = false;
  }
}