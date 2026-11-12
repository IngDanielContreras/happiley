import 'package:flutter/foundation.dart';
import 'music_manager.dart';

class MultimediaManager {
  // Instancia unica (Singleton) para gestionar el audio multimedia global
  static final MultimediaManager _instance = MultimediaManager._internal();
  factory MultimediaManager() => _instance;

  MultimediaManager._internal();

  // Notificadores reactivos de volumen (0.0 a 1.0) y estado de silencio
  final ValueNotifier<double> volumeNotifier = ValueNotifier<double>(1.0);
  final ValueNotifier<bool> isMutedNotifier = ValueNotifier<bool>(false);

  double _lastNonZeroVolume = 1.0;
  bool _hasPlayedInitialPromo = false;
  bool _isVideoPlaying = false;
  bool _isDuckingMusic = false;

  // Consulta si la reproduccion automatica inicial ya fue ejecutada en la sesion
  bool get hasPlayedInitialPromo => _hasPlayedInitialPromo;

  // Marcado de ejecucion unica de la reproduccion automatica inicial
  void markInitialPromoPlayed() {
    _hasPlayedInitialPromo = true;
  }

  // Volumen efectivo considerando el estado de silencio activo
  double get effectiveVolume =>
      isMutedNotifier.value ? 0.0 : volumeNotifier.value.clamp(0.0, 1.0);

  // Actualizacion del nivel de volumen multimedia general (0.0 a 1.0)
  void setVolume(double volume) {
    final clamped = volume.clamp(0.0, 1.0);
    volumeNotifier.value = clamped;

    if (clamped > 0.0) {
      _lastNonZeroVolume = clamped;
      if (isMutedNotifier.value) {
        isMutedNotifier.value = false;
      }
    } else {
      if (!isMutedNotifier.value) {
        isMutedNotifier.value = true;
      }
    }

    _syncMusicDucking();
  }

  // Silenciado inmediato conservando el ultimo nivel de volumen valido
  void mute() {
    if (!isMutedNotifier.value) {
      if (volumeNotifier.value > 0.0) {
        _lastNonZeroVolume = volumeNotifier.value;
      }
      isMutedNotifier.value = true;
      _syncMusicDucking();
    }
  }

  // Reactivacion del sonido restaurando el volumen previo
  void unmute() {
    if (isMutedNotifier.value) {
      isMutedNotifier.value = false;
      if (volumeNotifier.value <= 0.0) {
        volumeNotifier.value =
        _lastNonZeroVolume > 0.0 ? _lastNonZeroVolume : 1.0;
      }
      _syncMusicDucking();
    }
  }

  // Alternancia entre silencio y sonido activo
  void toggleMute() {
    if (isMutedNotifier.value || volumeNotifier.value <= 0.0) {
      unmute();
    } else {
      mute();
    }
  }

  // Registro del estado de reproduccion del video para coordinar musica de fondo
  void setVideoPlayingState(bool isPlaying) {
    _isVideoPlaying = isPlaying;
    _syncMusicDucking();
  }

  // Atenuacion de la musica ambiental mientras el video se reproduce con audio
  void _syncMusicDucking() {
    final bool shouldDuck = _isVideoPlaying && effectiveVolume > 0.0;

    if (shouldDuck && !_isDuckingMusic) {
      _isDuckingMusic = true;
      MusicManager().requestDuck();
    } else if (!shouldDuck && _isDuckingMusic) {
      _isDuckingMusic = false;
      MusicManager().releaseDuck();
    }
  }
}