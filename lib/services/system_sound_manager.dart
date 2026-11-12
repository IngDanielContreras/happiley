import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum SystemSoundType {
  dialogOpen,
  deniedNo,
  acceptYes,
  exitApp,
  error,
  alert,
  success,
}

class SystemSoundManager with WidgetsBindingObserver {
  // Instancia unica (Singleton) para gestionar los sonidos del sistema
  static final SystemSoundManager _instance = SystemSoundManager._internal();
  factory SystemSoundManager() => _instance;

  SystemSoundManager._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  // Reproductores independientes para apertura de dialogos y respuestas
  final AudioPlayer _dialogOpenPlayer = AudioPlayer();
  final AudioPlayer _feedbackPlayer = AudioPlayer();

  final ValueNotifier<int> volumePercentNotifier = ValueNotifier<int>(100);
  final Map<SystemSoundType, Uint8List> _soundCache = {};

  // Rutas fisicas de los archivos de audio del sistema
  static const Map<SystemSoundType, String> _assetPaths = {
    SystemSoundType.dialogOpen:
    'lib/assets/music/system_sounds/loading_dialog_alert_message.m4a',
    SystemSoundType.deniedNo:
    'lib/assets/music/system_sounds/denied_no_sound.m4a',
    SystemSoundType.acceptYes:
    'lib/assets/music/system_sounds/accept_yes_sound.m4a',
    SystemSoundType.exitApp:
    'lib/assets/music/system_sounds/exit_sound.m4a',
    SystemSoundType.error:
    'lib/assets/music/system_sounds/error_sound.m4a',
    SystemSoundType.alert:
    'lib/assets/music/system_sounds/alert_sound.m4a',
    SystemSoundType.success:
    'lib/assets/music/system_sounds/sound_success.m4a',
  };

  double get normalizedVolume =>
      (volumePercentNotifier.value.clamp(0, 100)) / 100.0;

  // Detencion inmediata de sonidos al pasar la aplicacion a segundo plano
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      stopAllSystemSounds();
    }
  }

  // Actualizacion continua del porcentaje de volumen en tiempo real
  Future<void> setVolumePercent(int percent) async {
    final int clampedPercent = percent.clamp(0, 100);
    volumePercentNotifier.value = clampedPercent;
    final double targetVolume = clampedPercent / 100.0;

    try {
      await _dialogOpenPlayer.setVolume(targetVolume);
      await _feedbackPlayer.setVolume(targetVolume);

      if (clampedPercent == 0) {
        await stopAllSystemSounds();
      }
    } catch (e) {
      debugPrint('Error al actualizar volumen de sonidos del sistema: $e');
    }
  }

  // Alternancia rapida entre silencio y volumen maximo
  Future<void> toggleMute() async {
    if (volumePercentNotifier.value > 0) {
      await setVolumePercent(0);
    } else {
      await setVolumePercent(100);
    }
  }

  // Carga en memoria de los bytes del recurso de audio
  Future<Uint8List?> _loadSoundBytes(SystemSoundType type) async {
    if (_soundCache.containsKey(type)) {
      return _soundCache[type];
    }

    final String? assetPath = _assetPaths[type];
    if (assetPath == null) return null;

    try {
      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      _soundCache[type] = bytes;
      return bytes;
    } catch (e) {
      debugPrint('Error al cargar el sonido del sistema ($assetPath): $e');
      return null;
    }
  }

  // Ejecucion del sonido aplicando el volumen porcentual configurado
  Future<void> playSound(SystemSoundType type) async {
    final int currentPercent = volumePercentNotifier.value;
    if (currentPercent <= 0) return;

    final Uint8List? bytes = await _loadSoundBytes(type);
    if (bytes == null) return;

    final double volume = currentPercent / 100.0;
    final AudioPlayer targetPlayer =
    type == SystemSoundType.dialogOpen ? _dialogOpenPlayer : _feedbackPlayer;

    try {
      await targetPlayer.stop();
      await targetPlayer.setReleaseMode(ReleaseMode.stop);
      await targetPlayer.setVolume(volume);
      await targetPlayer.play(BytesSource(bytes));
    } catch (e) {
      debugPrint('Error al reproducir sonido del sistema ($type): $e');
    }
  }

  Future<void> playDialogOpen() => playSound(SystemSoundType.dialogOpen);
  Future<void> playDeniedNo() => playSound(SystemSoundType.deniedNo);
  Future<void> playAcceptYes() => playSound(SystemSoundType.acceptYes);
  Future<void> playExit() => playSound(SystemSoundType.exitApp);
  Future<void> playError() => playSound(SystemSoundType.error);
  Future<void> playAlert() => playSound(SystemSoundType.alert);
  Future<void> playSuccess() => playSound(SystemSoundType.success);

  // Detencion de todos los reproductores activos del sistema
  Future<void> stopAllSystemSounds() async {
    try {
      await _dialogOpenPlayer.stop();
      await _feedbackPlayer.stop();
    } catch (e) {
      debugPrint('Error al detener sonidos del sistema: $e');
    }
  }

  // Liberacion de recursos en memoria
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await stopAllSystemSounds();
    await _dialogOpenPlayer.dispose();
    await _feedbackPlayer.dispose();
  }
}