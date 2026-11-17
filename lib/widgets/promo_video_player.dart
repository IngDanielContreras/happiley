import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _isFullscreen = false;
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

    final bool shouldAutoPlay = !_multimediaManager.hasPlayedInitialPromo;

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
        value.position >= value.duration - const Duration(milliseconds: 120);

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

  // Alternancia directa entre reproducir y pausar el video
  Future<void> _togglePlayPause() async {
    final controller = _controller;
    if (controller == null || !_isInitialized) return;

    if (controller.value.isPlaying) {
      _hideControlsTimer?.cancel();
      await controller.pause();
      _multimediaManager.setVideoPlayingState(false);

      if (mounted) {
        setState(() {
          _controlsVisible = true;
        });
      }
    } else {
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
          _controlsVisible = true;
        });
        _scheduleAutoHideControls();
      }
    }
  }

  // Apertura del modo de pantalla completa conservando estado y controles
  Future<void> _enterFullscreen() async {
    final controller = _controller;
    if (controller == null || !_isInitialized || _isFullscreen) return;

    _hideControlsTimer?.cancel();

    setState(() {
      _isFullscreen = true;
    });

    final bool isLandscapeVideo = controller.value.aspectRatio >= 1.0;

    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations(
        isLandscapeVideo
            ? const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]
            : const [
          DeviceOrientation.portraitUp,
        ],
      );

      if (!mounted) return;

      await Navigator.of(context, rootNavigator: true).push<void>(
        PageRouteBuilder<void>(
          pageBuilder: (routeContext, animation, secondaryAnimation) {
            return _FullscreenVideoPlayerPage(
              controller: controller,
              multimediaManager: _multimediaManager,
              onTogglePlayPause: _togglePlayPause,
            );
          },
          transitionDuration: const Duration(milliseconds: 200),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
    } finally {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations(const []);

      if (mounted) {
        setState(() {
          _isFullscreen = false;
        });
        if (_controlsVisible && controller.value.isPlaying) {
          _scheduleAutoHideControls();
        }
      }
    }
  }

  // Manejo de pulsacion sobre la superficie del video para reproducir o alternar controles
  Future<void> _handleVideoSurfaceTap() async {
    if (!widget.isActive) return;

    final controller = _controller;

    if (controller == null || !_isInitialized) {
      await _startVideoPlayback(autoPlay: true);
      return;
    }

    if (!controller.value.isPlaying && !_controlsVisible) {
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

    if (_controlsVisible && controller.value.isPlaying) {
      _scheduleAutoHideControls();
    } else {
      _hideControlsTimer?.cancel();
    }
  }

  // Programacion del ocultamiento automatico de controles tras inactividad
  void _scheduleAutoHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      final controller = _controller;
      if (mounted &&
          _controlsVisible &&
          !_isDraggingProgress &&
          (controller?.value.isPlaying ?? false)) {
        setState(() {
          _controlsVisible = false;
        });
      }
    });
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
            : _isFullscreen
            ? const ColoredBox(color: Colors.black)
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
            _VideoControlsOverlay(
              controller: controller,
              multimediaManager: _multimediaManager,
              controlsVisible: _controlsVisible,
              isDraggingProgress: _isDraggingProgress,
              dragProgressValue: _dragProgressValue,
              isFullscreen: false,
              onTogglePlayPause: _togglePlayPause,
              onToggleFullscreen: _enterFullscreen,
              onUserInteraction: _scheduleAutoHideControls,
              onProgressDragStart: (val) {
                _hideControlsTimer?.cancel();
                setState(() {
                  _isDraggingProgress = true;
                  _dragProgressValue = val;
                });
              },
              onProgressDragUpdate: (val) {
                setState(() {
                  _dragProgressValue = val;
                });
              },
              onProgressDragEnd: (val) async {
                final totalMs =
                    controller.value.duration.inMilliseconds;
                final targetMs = (totalMs * val).round();

                await controller.seekTo(
                  Duration(milliseconds: targetMs),
                );

                if (mounted) {
                  setState(() {
                    _isDraggingProgress = false;
                  });
                  if (controller.value.isPlaying) {
                    _scheduleAutoHideControls();
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Vista dedicada de pantalla completa sincronizada con el reproductor activo
class _FullscreenVideoPlayerPage extends StatefulWidget {
  final VideoPlayerController controller;
  final MultimediaManager multimediaManager;
  final Future<void> Function() onTogglePlayPause;

  const _FullscreenVideoPlayerPage({
    required this.controller,
    required this.multimediaManager,
    required this.onTogglePlayPause,
  });

  @override
  State<_FullscreenVideoPlayerPage> createState() =>
      _FullscreenVideoPlayerPageState();
}

class _FullscreenVideoPlayerPageState
    extends State<_FullscreenVideoPlayerPage> {
  bool _controlsVisible = true;
  bool _isDraggingProgress = false;
  double _dragProgressValue = 0.0;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onPlayerStateChanged);
    widget.multimediaManager.volumeNotifier.addListener(_onPlayerStateChanged);
    widget.multimediaManager.isMutedNotifier.addListener(_onPlayerStateChanged);

    if (widget.controller.value.isPlaying) {
      _scheduleAutoHideControls();
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    widget.controller.removeListener(_onPlayerStateChanged);
    widget.multimediaManager.volumeNotifier
        .removeListener(_onPlayerStateChanged);
    widget.multimediaManager.isMutedNotifier
        .removeListener(_onPlayerStateChanged);
    super.dispose();
  }

  // Sincronizacion visual ante cambios de reproduccion o volumen
  void _onPlayerStateChanged() {
    if (!mounted) return;
    setState(() {});
  }

  // Programacion del ocultamiento automatico de controles en pantalla completa
  void _scheduleAutoHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted &&
          _controlsVisible &&
          !_isDraggingProgress &&
          widget.controller.value.isPlaying) {
        setState(() {
          _controlsVisible = false;
        });
      }
    });
  }

  // Alternancia de visibilidad de controles al tocar la pantalla completa
  void _handleFullscreenSurfaceTap() {
    setState(() {
      _controlsVisible = !_controlsVisible;
    });

    if (_controlsVisible && widget.controller.value.isPlaying) {
      _scheduleAutoHideControls();
    } else {
      _hideControlsTimer?.cancel();
    }
  }

  // Cierre controlado del modo de pantalla completa
  void _exitFullscreen() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final double aspectRatio = widget.controller.value.aspectRatio > 0
        ? widget.controller.value.aspectRatio
        : 16 / 9;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleFullscreenSurfaceTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: aspectRatio,
                  child: VideoPlayer(widget.controller),
                ),
              ),
              SafeArea(
                child: _VideoControlsOverlay(
                  controller: widget.controller,
                  multimediaManager: widget.multimediaManager,
                  controlsVisible: _controlsVisible,
                  isDraggingProgress: _isDraggingProgress,
                  dragProgressValue: _dragProgressValue,
                  isFullscreen: true,
                  onTogglePlayPause: () async {
                    await widget.onTogglePlayPause();
                    if (mounted) {
                      setState(() {
                        _controlsVisible = true;
                      });
                      if (widget.controller.value.isPlaying) {
                        _scheduleAutoHideControls();
                      } else {
                        _hideControlsTimer?.cancel();
                      }
                    }
                  },
                  onToggleFullscreen: _exitFullscreen,
                  onUserInteraction: _scheduleAutoHideControls,
                  onProgressDragStart: (val) {
                    _hideControlsTimer?.cancel();
                    setState(() {
                      _isDraggingProgress = true;
                      _dragProgressValue = val;
                    });
                  },
                  onProgressDragUpdate: (val) {
                    setState(() {
                      _dragProgressValue = val;
                    });
                  },
                  onProgressDragEnd: (val) async {
                    final totalMs =
                        widget.controller.value.duration.inMilliseconds;
                    final targetMs = (totalMs * val).round();

                    await widget.controller.seekTo(
                      Duration(milliseconds: targetMs),
                    );

                    if (mounted) {
                      setState(() {
                        _isDraggingProgress = false;
                      });
                      if (widget.controller.value.isPlaying) {
                        _scheduleAutoHideControls();
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Superposicion reutilizable de controles interactivos del reproductor
class _VideoControlsOverlay extends StatelessWidget {
  final VideoPlayerController controller;
  final MultimediaManager multimediaManager;
  final bool controlsVisible;
  final bool isDraggingProgress;
  final double dragProgressValue;
  final bool isFullscreen;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onUserInteraction;
  final ValueChanged<double> onProgressDragStart;
  final ValueChanged<double> onProgressDragUpdate;
  final Future<void> Function(double) onProgressDragEnd;

  const _VideoControlsOverlay({
    required this.controller,
    required this.multimediaManager,
    required this.controlsVisible,
    required this.isDraggingProgress,
    required this.dragProgressValue,
    required this.isFullscreen,
    required this.onTogglePlayPause,
    required this.onToggleFullscreen,
    required this.onUserInteraction,
    required this.onProgressDragStart,
    required this.onProgressDragUpdate,
    required this.onProgressDragEnd,
  });

  // Seleccion dinamica del icono segun el nivel real de volumen
  IconData _getVolumeIcon(double effectiveVolume) {
    final int percentage = (effectiveVolume.clamp(0.0, 1.0) * 100).round();
    if (percentage <= 0) {
      return Icons.volume_off_rounded;
    } else if (percentage < 34) {
      return Icons.volume_mute_rounded;
    } else if (percentage < 100) {
      return Icons.volume_down_rounded;
    } else {
      return Icons.volume_up_rounded;
    }
  }

  // Formateo de la duracion del video en formato minutos y segundos
  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds.clamp(0, 359999);
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    final totalMs = value.duration.inMilliseconds;
    final currentMs = value.position.inMilliseconds;

    final double progressRatio = totalMs > 0
        ? (isDraggingProgress
        ? dragProgressValue
        : (currentMs / totalMs).clamp(0.0, 1.0))
        : 0.0;

    final double effectiveVolume = multimediaManager.effectiveVolume;
    final bool isMuted = effectiveVolume <= 0.0;
    final IconData volumeIcon = _getVolumeIcon(effectiveVolume);
    final bool isPlaying = value.isPlaying;
    final IconData playPauseIcon =
    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded;
    final IconData fullscreenIcon = isFullscreen
        ? Icons.fullscreen_exit_rounded
        : Icons.fullscreen_rounded;

    return Positioned.fill(
      child: AnimatedOpacity(
        opacity: controlsVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !controlsVisible,
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
            padding: EdgeInsets.symmetric(
              horizontal: isFullscreen ? 20 : 14,
              vertical: isFullscreen ? 14 : 10,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Fila superior con boton unificado de sonido, barra de volumen y pantalla completa
                Row(
                  children: [
                    _ControlIconButton(
                      icon: volumeIcon,
                      tooltip: isMuted ? 'Activar sonido' : 'Silenciar',
                      isActive: !isMuted,
                      onPressed: () {
                        multimediaManager.toggleMute();
                        onUserInteraction();
                      },
                    ),
                    const SizedBox(width: 8),
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
                          value: effectiveVolume,
                          min: 0.0,
                          max: 1.0,
                          onChanged: (newVal) {
                            multimediaManager.setVolume(newVal);
                            onUserInteraction();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ControlIconButton(
                      icon: fullscreenIcon,
                      tooltip: isFullscreen
                          ? 'Salir de pantalla completa'
                          : 'Pantalla completa',
                      isActive: isFullscreen,
                      onPressed: onToggleFullscreen,
                    ),
                  ],
                ),
                // Boton central animado de reproduccion y pausa
                Center(
                  child: _ControlIconButton(
                    icon: playPauseIcon,
                    tooltip: isPlaying ? 'Pausar' : 'Reproducir',
                    isActive: isPlaying,
                    size: isFullscreen ? 50 : 42,
                    iconSize: isFullscreen ? 28 : 24,
                    borderRadius: 14,
                    onPressed: onTogglePlayPause,
                  ),
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
                        onChangeStart: onProgressDragStart,
                        onChanged: onProgressDragUpdate,
                        onChangeEnd: onProgressDragEnd,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(
                              isDraggingProgress
                                  ? Duration(
                                milliseconds:
                                (totalMs * dragProgressValue).round(),
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
}

// Boton modular auxiliar con animacion coherente para los controles del reproductor
class _ControlIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;
  final double borderRadius;

  const _ControlIconButton({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.onPressed,
    this.size = 34,
    this.iconSize = 19,
    this.borderRadius = 10,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF5548F5);
    const inactiveColor = Color(0x73000000);

    return Tooltip(
      message: tooltip,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isActive ? activeColor : inactiveColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: IconButton(
          padding: EdgeInsets.zero,
          iconSize: iconSize,
          color: Colors.white,
          onPressed: onPressed,
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
              icon,
              key: ValueKey<IconData>(icon),
            ),
          ),
        ),
      ),
    );
  }
}