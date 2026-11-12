import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../services/multimedia_manager.dart';

// Componente reproductor de video promocional para la interfaz de carrito
class PromoVideoPlayer extends StatefulWidget {
  final bool isActive;

  const PromoVideoPlayer({
    super.key,
    this.isActive = false,
  });

  @override
  State<PromoVideoPlayer> createState() => _PromoVideoPlayerState();
}

class _PromoVideoPlayerState extends State<PromoVideoPlayer>
    with WidgetsBindingObserver {
  // Ruta del recurso de video promocional en los assets del proyecto
  static const String _videoAssetPath =
      'lib/assets/videos/welcome_happiley.mp4';

  // Instancia del gestor multimedia global para control de volumen y atenuacion
  final MultimediaManager _multimediaManager = MultimediaManager();

  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _controlsVisible = false;
  bool _isDraggingProgress = false;
  bool _wasPlayingBeforePause = false;
  bool _isStartingPlayback = false;
  bool _isHandlingVideoEnd = false;
  double _dragProgressValue = 0.0;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _multimediaManager.volumeNotifier.addListener(_onAudioSettingsChanged);
    _multimediaManager.isMutedNotifier.addListener(_onAudioSettingsChanged);

    // Activacion inicial si la pestana del carrito se encuentra activa de entrada
    if (widget.isActive) {
      _activateVideoPlayer();
    }
  }

  @override
  void didUpdateWidget(covariant PromoVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Deteccion de cambio de visibilidad de pestana para pausar o reproducir
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _activateVideoPlayer();
      } else {
        _deactivateVideoPlayer();
      }
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _multimediaManager.volumeNotifier.removeListener(_onAudioSettingsChanged);
    _multimediaManager.isMutedNotifier.removeListener(_onAudioSettingsChanged);
    _multimediaManager.setVideoPlayingState(false);
    _disposeVideoController();
    super.dispose();
  }

  // Activacion y carga controlada del reproductor al visualizar la pestana
  Future<void> _activateVideoPlayer() async {
    if (!widget.isActive || _isStartingPlayback) return;

    if (_controller != null && _isInitialized) {
      return;
    }

    final bool shouldAutoPlay =
    !_multimediaManager.hasPlayedInitialPromo;

    if (shouldAutoPlay) {
      _multimediaManager.markInitialPromoPlayed();
    }

    await _startVideoPlayback(autoPlay: shouldAutoPlay);
  }

  // Desactivacion y pausa del video al salir de la pestana actual
  Future<void> _deactivateVideoPlayer() async {
    _hideControlsTimer?.cancel();
    _wasPlayingBeforePause = false;

    final controller = _controller;

    if (controller != null && controller.value.isPlaying) {
      await controller.pause();
    }

    _multimediaManager.setVideoPlayingState(false);

    if (mounted) {
      setState(() {
        _controlsVisible = false;
      });
    }
  }

  // Gestion del ciclo de vida de la aplicacion para pausar o reanudar el video
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !_isInitialized) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      if (controller.value.isPlaying) {
        _wasPlayingBeforePause = true;
        controller.pause();
        _multimediaManager.setVideoPlayingState(false);
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_wasPlayingBeforePause && widget.isActive) {
        _wasPlayingBeforePause = false;
        controller.play();
        _multimediaManager.setVideoPlayingState(true);
      }
    }
  }

  // Sincronizacion de volumen ante modificaciones globales o locales
  void _onAudioSettingsChanged() {
    final controller = _controller;
    if (controller != null && _isInitialized) {
      controller.setVolume(_multimediaManager.effectiveVolume);
    }
    if (mounted) {
      setState(() {});
    }
  }

  // Inicializacion y arranque del controlador de video
  Future<void> _startVideoPlayback({required bool autoPlay}) async {
    if (_isStartingPlayback) return;
    _isStartingPlayback = true;

    try {
      await _disposeVideoController();

      final controller = VideoPlayerController.asset(_videoAssetPath);
      _controller = controller;

      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(_multimediaManager.effectiveVolume);
      await controller.seekTo(Duration.zero);

      controller.addListener(_onVideoTick);

      if (!mounted) {
        await _disposeVideoController();
        return;
      }

      setState(() {
        _isInitialized = true;
        _controlsVisible = false;
      });

      if (autoPlay && widget.isActive) {
        await controller.play();
        _multimediaManager.setVideoPlayingState(true);
      }
    } catch (e) {
      debugPrint('Error al inicializar video promocional: $e');
      _multimediaManager.setVideoPlayingState(false);

      if (mounted) {
        setState(() {
          _isInitialized = false;
          _controlsVisible = false;
        });
      }
    } finally {
      _isStartingPlayback = false;
    }
  }

  // Supervision constante del reproductor para detectar finalizacion del video
  void _onVideoTick() {
    final controller = _controller;
    if (controller == null ||
        !_isInitialized ||
        !mounted ||
        _isHandlingVideoEnd) {
      return;
    }

    final value = controller.value;

    final bool hasEnded = value.duration > Duration.zero &&
        !value.isPlaying &&
        value.position >=
            value.duration - const Duration(milliseconds: 120);

    if (hasEnded && !_isDraggingProgress) {
      _resetVideoAfterCompletion();
      return;
    }

    if (!_isDraggingProgress) {
      setState(() {});
    }
  }

  // Restablecimiento del video al completarse la reproduccion
  Future<void> _resetVideoAfterCompletion() async {
    if (_isHandlingVideoEnd) return;

    _isHandlingVideoEnd = true;
    _hideControlsTimer?.cancel();
    _multimediaManager.setVideoPlayingState(false);

    final controller = _controller;

    try {
      if (controller != null) {
        await controller.pause();
        await controller.seekTo(Duration.zero);
      }

      if (mounted) {
        setState(() {
          _controlsVisible = false;
          _isDraggingProgress = false;
          _dragProgressValue = 0.0;
        });
      }
    } catch (e) {
      debugPrint('Error al reiniciar el video promocional: $e');
    } finally {
      _isHandlingVideoEnd = false;
    }
  }

  // Liberacion segura de recursos del reproductor de video
  Future<void> _disposeVideoController() async {
    final controller = _controller;
    _controller = null;

    if (controller != null) {
      controller.removeListener(_onVideoTick);
      await controller.pause();
      await controller.dispose();
    }
  }

  // Manejo de pulsacion sobre la superficie del video para reproducir, pausar o mostrar controles
  Future<void> _handleVideoSurfaceTap() async {
    if (!widget.isActive) return;

    final controller = _controller;

    if (controller == null || !_isInitialized) {
      await _startVideoPlayback(autoPlay: true);
      return;
    }

    if (!controller.value.isPlaying) {
      _hideControlsTimer?.cancel();

      if (controller.value.duration > Duration.zero &&
          controller.value.position >=
              controller.value.duration -
                  const Duration(milliseconds: 120)) {
        await controller.seekTo(Duration.zero);
      }

      await controller.play();
      _multimediaManager.setVideoPlayingState(true);

      if (mounted) {
        setState(() {
          _controlsVisible = false;
        });
      }
      return;
    }

    setState(() {
      _controlsVisible = !_controlsVisible;
    });

    if (_controlsVisible) {
      _scheduleAutoHideControls();
    } else {
      _hideControlsTimer?.cancel();
    }
  }

  // Programacion del ocultamiento automatico de controles tras inactividad
  void _scheduleAutoHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _controlsVisible && !_isDraggingProgress) {
        setState(() {
          _controlsVisible = false;
        });
      }
    });
  }

  // Formateo de la duracion del video en formato minutos y segundos
  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds.clamp(0, 359999);
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // Superposicion de controles interactivos del reproductor
  Widget _buildInteractiveControlsOverlay(
      VideoPlayerController controller) {
    final value = controller.value;
    final totalMs = value.duration.inMilliseconds;
    final currentMs = value.position.inMilliseconds;

    final double progressRatio = totalMs > 0
        ? (_isDraggingProgress
        ? _dragProgressValue
        : (currentMs / totalMs).clamp(0.0, 1.0))
        : 0.0;

    final bool isMuted = _multimediaManager.effectiveVolume <= 0.0;
    final double currentVolume = _multimediaManager.effectiveVolume;

    return Positioned.fill(
      child: AnimatedOpacity(
        opacity: _controlsVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !_controlsVisible,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.72),
                ],
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Fila superior con controles de volumen y ajustes
                Row(
                  children: [
                    _ControlIconButton(
                      icon: Icons.volume_off_rounded,
                      tooltip: 'Silenciar',
                      isActive: isMuted,
                      onPressed: () {
                        _multimediaManager.mute();
                        _scheduleAutoHideControls();
                      },
                    ),
                    const SizedBox(width: 6),
                    _ControlIconButton(
                      icon: Icons.volume_up_rounded,
                      tooltip: 'Activar sonido',
                      isActive: !isMuted,
                      onPressed: () {
                        _multimediaManager.unmute();
                        _scheduleAutoHideControls();
                      },
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12,
                          ),
                          activeTrackColor: const Color(0xFF5548F5),
                          inactiveTrackColor: Colors.white38,
                          thumbColor: Colors.white,
                        ),
                        child: Slider(
                          value: currentVolume,
                          min: 0.0,
                          max: 1.0,
                          onChanged: (newVal) {
                            _multimediaManager.setVolume(newVal);
                            _scheduleAutoHideControls();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: 'Pantalla completa no disponible',
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          iconSize: 20,
                          onPressed: null,
                          icon: Icon(
                            Icons.fullscreen_rounded,
                            color: Colors.white.withValues(alpha: 0.38),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Fila inferior con barra de progreso y temporizador
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 13,
                        ),
                        activeTrackColor: const Color(0xFF5548F5),
                        inactiveTrackColor: Colors.white38,
                        thumbColor: Colors.white,
                      ),
                      child: Slider(
                        value: progressRatio,
                        min: 0.0,
                        max: 1.0,
                        onChangeStart: (val) {
                          _hideControlsTimer?.cancel();
                          setState(() {
                            _isDraggingProgress = true;
                            _dragProgressValue = val;
                          });
                        },
                        onChanged: (val) {
                          setState(() {
                            _dragProgressValue = val;
                          });
                        },
                        onChangeEnd: (val) async {
                          final targetMs = (totalMs * val).round();

                          await controller.seekTo(
                            Duration(milliseconds: targetMs),
                          );

                          if (mounted) {
                            setState(() {
                              _isDraggingProgress = false;
                            });
                            _scheduleAutoHideControls();
                          }
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(
                              _isDraggingProgress
                                  ? Duration(
                                milliseconds:
                                (totalMs * _dragProgressValue)
                                    .round(),
                              )
                                  : value.position,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _formatDuration(value.duration),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return GestureDetector(
      onTap: _handleVideoSurfaceTap,
      child: Container(
        width: double.infinity,
        height: 195,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFE1E5EB),
          ),
        ),
        child: !_isInitialized || controller == null
            ? const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF5548F5),
          ),
        )
            : Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width > 0
                    ? controller.value.size.width
                    : 16,
                height: controller.value.size.height > 0
                    ? controller.value.size.height
                    : 9,
                child: VideoPlayer(controller),
              ),
            ),
            _buildInteractiveControlsOverlay(controller),
          ],
        ),
      ),
    );
  }
}

// Boton modular auxiliar para los controles del reproductor
class _ControlIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onPressed;

  const _ControlIconButton({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF5548F5);
    const inactiveColor = Color(0x73000000);

    return Tooltip(
      message: tooltip,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: isActive ? activeColor : inactiveColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: IconButton(
          padding: EdgeInsets.zero,
          iconSize: 19,
          color: Colors.white,
          onPressed: onPressed,
          icon: Icon(icon),
        ),
      ),
    );
  }
}