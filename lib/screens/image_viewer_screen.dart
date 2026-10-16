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

  // Ajuste del nivel de zoom
  void _updateScale(double newScale) {
    setState(() {
      _currentScale = newScale.clamp(1.0, 4.0);
      _transformationController.value = Matrix4.diagonal3Values(
        _currentScale,
        _currentScale,
        1.0,
      );
    });
  }

  // Aumento gradual del tamaño de la imagen
  void _zoomIn() {
    _updateScale(_currentScale + 0.25);
  }

  // Disminucion gradual del tamaño de la imagen
  void _zoomOut() {
    _updateScale(_currentScale - 0.25);
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
      backgroundColor: Color(0xFFE3E2E2),
      body: SafeArea(
        child: Stack(
          children: [
            // Visor interactivo para manipular el zoom y desplazamiento de la imagen
            Center(
              child: InteractiveViewer(
                transformationController: _transformationController,
                minScale: 1.0,
                maxScale: 4.0,
                onInteractionUpdate: (details) {
                  setState(() {
                    _currentScale =
                    _transformationController.value.storage[0];
                  });
                },
                child: Image.asset(
                  widget.imagePath,
                  fit: BoxFit.contain,
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
                bottom: 20,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Color(0xFFFFFFFF),
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
                          inactiveColor: Color(0xFFBBBBC1),
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