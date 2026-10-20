import 'dart:io';
import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';

class ImageViewerScreen extends StatefulWidget {
  final String imagePath;

  const ImageViewerScreen({
    super.key,
    required this.imagePath,
  });

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  final TransformationController _transformationController =
  TransformationController();
  double _currentScale = 1.0;
  bool _showSlider = false;

  // Actualizacion progresiva del zoom manteniendo la fluidez y posicion
  void _updateScale(double newScale) {
    final double clampedScale = newScale.clamp(1.0, 4.0);

    if (clampedScale == 1.0) {
      setState(() {
        _currentScale = 1.0;
        _transformationController.value = Matrix4.identity();
      });
      return;
    }

    final Matrix4 currentMatrix = _transformationController.value;
    final double oldScale = currentMatrix.storage[0];

    if (oldScale == 0) return;
    final double scaleFactor = clampedScale / oldScale;

    final Size size = MediaQuery.of(context).size;
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;

    final double currentTx = currentMatrix.storage[12];
    final double currentTy = currentMatrix.storage[13];

    final double newTx = centerX - scaleFactor * (centerX - currentTx);
    final double newTy = centerY - scaleFactor * (centerY - currentTy);

    setState(() {
      _currentScale = clampedScale;
      _transformationController.value = Matrix4.identity()
        ..translate(newTx, newTy)
        ..scale(clampedScale, clampedScale, 1.0);
    });
  }

  // Aumento gradual de la escala de la imagen
  void _zoomIn() {
    _updateScale(_currentScale + 0.25);
  }

  // Disminucion gradual de la escala de la imagen
  void _zoomOut() {
    _updateScale(_currentScale - 0.25);
  }

  // Renderizado dinamico de la imagen segun su origen local o de assets
  Widget _buildImage(String path) {
    final file = File(path);
    if (path.startsWith('/') || file.existsSync()) {
      return Image.file(
        file,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.broken_image,
          color: Colors.black54,
          size: 64,
        ),
      );
    }
    return Image.asset(
      path,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => const Icon(
        Icons.broken_image,
        color: Colors.black54,
        size: 64,
      ),
    );
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar.statusOnly(),
      backgroundColor: const Color(0xFFE3E2E2),
      body: SafeArea(
        child: Stack(
          children: [
            // Visor interactivo delimitado para evitar desbordamientos en pantalla
            Positioned.fill(
              child: ClipRect(
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 1.0,
                  maxScale: 4.0,
                  panEnabled: _currentScale > 1.0,
                  scaleEnabled: true,
                  boundaryMargin: EdgeInsets.zero,
                  clipBehavior: Clip.hardEdge,
                  onInteractionUpdate: (details) {
                    final double scale =
                    _transformationController.value.storage[0];
                    setState(() {
                      _currentScale = scale;
                    });
                  },
                  onInteractionEnd: (details) {
                    final double scale =
                    _transformationController.value.storage[0];
                    if (scale <= 1.0) {
                      setState(() {
                        _currentScale = 1.0;
                        _transformationController.value = Matrix4.identity();
                      });
                    }
                  },
                  child: Center(
                    child: _buildImage(widget.imagePath),
                  ),
                ),
              ),
            ),

            // Boton para regresar a la pantalla anterior
            Positioned(
              top: 10,
              left: 10,
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),

            // Controles superiores derechos para ajuste rapido de zoom
            Positioned(
              top: 10,
              right: 10,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: const Icon(Icons.zoom_out, color: Colors.black),
                      onPressed: _zoomOut,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: const Icon(Icons.zoom_in, color: Colors.black),
                      onPressed: _zoomIn,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: Icon(
                        _showSlider ? Icons.tune : Icons.linear_scale,
                        color: Colors.black,
                      ),
                      onPressed: () {
                        setState(() {
                          _showSlider = !_showSlider;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Barra desplegable inferior con deslizador para regular el nivel de zoom
            if (_showSlider)
              Positioned(
                bottom: 28,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white24,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.zoom_out,
                        color: Colors.black,
                        size: 20,
                      ),
                      Expanded(
                        child: Slider(
                          value: _currentScale,
                          min: 1.0,
                          max: 4.0,
                          activeColor: const Color(0xFF5548F5),
                          inactiveColor: const Color(0xFFBBBBC1),
                          onChanged: (value) {
                            _updateScale(value);
                          },
                        ),
                      ),
                      const Icon(
                        Icons.zoom_in,
                        color: Colors.black,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}