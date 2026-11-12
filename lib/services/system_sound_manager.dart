import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'music_manager.dart';

enum SystemSoundType {
  dialogOpen,
  deniedNo,
  acceptYes,
  exitApp,
  error,
  alert,
  success,
  addArticle,
  removeArticle,
}

class SystemSoundManager with WidgetsBindingObserver {
  // Instancia unica (Singleton) para gestionar los sonidos del sistema
  static final SystemSoundManager _instance = SystemSoundManager._internal();
  factory SystemSoundManager() => _instance;

  SystemSoundManager._internal() {
    WidgetsBinding.instance.addObserver(this);
    _initPlayers();
  }

  // Reproductores independientes para apertura de dialogos y respuestas
  final AudioPlayer _dialogOpenPlayer = AudioPlayer();
  final AudioPlayer _feedbackPlayer = AudioPlayer();

  final ValueNotifier<int> volumePercentNotifier = ValueNotifier<int>(100);
  final Map<SystemSoundType, Uint8List> _soundCache = {};

  bool _dialogPlayerDucking = false;
  bool _feedbackPlayerDucking = false;
  Timer? _dialogSafetyTimer;
  Timer? _feedbackSafetyTimer;
  StreamSubscription<void>? _dialogCompleteSub;
  StreamSubscription<void>? _feedbackCompleteSub;

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
    SystemSoundType.addArticle:
    'lib/assets/music/system_sounds/add_article_sound.m4a',
    SystemSoundType.removeArticle:
    'lib/assets/music/system_sounds/remove_article_sound.m4a',
  };

  Future<void> _initPlayers() async {
    final context = AudioContext(
      android: const AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: false,
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.assistanceSonification,
        audioFocus: AndroidAudioFocus.none,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.ambient,
      ),
    );

    try {
      await _dialogOpenPlayer.setAudioContext(context);
      await _feedbackPlayer.setAudioContext(context);
      await _dialogOpenPlayer.setReleaseMode(ReleaseMode.stop);
      await _feedbackPlayer.setReleaseMode(ReleaseMode.stop);
    } catch (e) {
      debugPrint('Error al configurar reproductores de sonidos del sistema: $e');
    }

    _dialogCompleteSub = _dialogOpenPlayer.onPlayerComplete.listen((_) {
      _releaseDialogDuck();
    });

    _feedbackCompleteSub = _feedbackPlayer.onPlayerComplete.listen((_) {
      _releaseFeedbackDuck();
    });
  }

  void _acquireDialogDuck() {
    _dialogSafetyTimer?.cancel();
    if (!_dialogPlayerDucking) {
      _dialogPlayerDucking = true;
      MusicManager().requestDuck();
    }
    _dialogSafetyTimer = Timer(const Duration(seconds: 4), () {
      _releaseDialogDuck();
    });
  }

  void _releaseDialogDuck() {
    _dialogSafetyTimer?.cancel();
    if (_dialogPlayerDucking) {
      _dialogPlayerDucking = false;
      MusicManager().releaseDuck();
    }
  }

  void _acquireFeedbackDuck() {
    _feedbackSafetyTimer?.cancel();
    if (!_feedbackPlayerDucking) {
      _feedbackPlayerDucking = true;
      MusicManager().requestDuck();
    }
    _feedbackSafetyTimer = Timer(const Duration(seconds: 4), () {
      _releaseFeedbackDuck();
    });
  }

  void _releaseFeedbackDuck() {
    _feedbackSafetyTimer?.cancel();
    if (_feedbackPlayerDucking) {
      _feedbackPlayerDucking = false;
      MusicManager().releaseDuck();
    }
  }

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
    final bool isDialogSound = type == SystemSoundType.dialogOpen;
    final AudioPlayer targetPlayer =
    isDialogSound ? _dialogOpenPlayer : _feedbackPlayer;

    try {
      if (isDialogSound) {
        _acquireDialogDuck();
      } else {
        _acquireFeedbackDuck();
      }

      if (targetPlayer.state == PlayerState.playing ||
          targetPlayer.state == PlayerState.paused) {
        await targetPlayer.stop();
      }
      await targetPlayer.release();
      await targetPlayer.setReleaseMode(ReleaseMode.stop);
      await targetPlayer.setVolume(volume);
      await targetPlayer.play(BytesSource(bytes));
    } catch (e) {
      if (isDialogSound) {
        _releaseDialogDuck();
      } else {
        _releaseFeedbackDuck();
      }
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
  Future<void> playAddArticle() => playSound(SystemSoundType.addArticle);
  Future<void> playRemoveArticle() => playSound(SystemSoundType.removeArticle);

  // Detencion de todos los reproductores activos del sistema
  Future<void> stopAllSystemSounds() async {
    try {
      await _dialogOpenPlayer.stop();
      await _feedbackPlayer.stop();
    } catch (e) {
      debugPrint('Error al detener sonidos del sistema: $e');
    } finally {
      _releaseDialogDuck();
      _releaseFeedbackDuck();
    }
  }

  // Liberacion de recursos en memoria
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await _dialogCompleteSub?.cancel();
    await _feedbackCompleteSub?.cancel();
    await stopAllSystemSounds();
    await _dialogOpenPlayer.dispose();
    await _feedbackPlayer.dispose();
  }
}