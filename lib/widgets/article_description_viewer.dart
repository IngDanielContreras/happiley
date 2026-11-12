import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class ArticleDescriptionViewer extends StatefulWidget {
  final String description;

  const ArticleDescriptionViewer({
    super.key,
    required this.description,
  });

  @override
  State<ArticleDescriptionViewer> createState() =>
      _ArticleDescriptionViewerState();
}

class _ArticleDescriptionViewerState
    extends State<ArticleDescriptionViewer> {
  QuillController? _controller;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  @override
  void didUpdateWidget(covariant ArticleDescriptionViewer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.description != widget.description) {
      _disposeController();
      _initializeController();
    }
  }

  // Inicializacion del controlador en modo solo lectura si la descripcion es JSON Delta
  void _initializeController() {
    if (widget.description.isEmpty) return;

    try {
      final List<dynamic> jsonDelta = jsonDecode(widget.description);
      final document = Document.fromJson(jsonDelta);

      _controller = QuillController(
        document: document,
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
    } catch (_) {
      _controller = null;
    }
  }

  // Liberacion de recursos del controlador de texto
  void _disposeController() {
    _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.description.isEmpty) {
      return const Text(
        'Sin descripción disponible.',
        style: TextStyle(
          color: Color(0xFF616161),
          fontSize: 14,
        ),
      );
    }

    // Renderizado de texto plano seleccionable para articulos precargados
    if (_controller == null) {
      return SelectableText(
        widget.description,
        style: const TextStyle(
          color: Color(0xFF616161),
          fontSize: 14,
        ),
      );
    }

    // Renderizado de texto sin cursor para articulos publicados
    return QuillEditor.basic(
      controller: _controller!,
      config: QuillEditorConfig(
        autoFocus: false,
        expands: false,
        showCursor: false,
        enableInteractiveSelection: true,
        customStyles: DefaultStyles(
          paragraph: DefaultTextBlockStyle(
            const TextStyle(
              color: Color(0xFF616161),
              fontSize: 14,
            ),
            const HorizontalSpacing(0, 0),
            const VerticalSpacing(0, 0),
            const VerticalSpacing(0, 0),
            null,
          ),
        ),
      ),
    );
  }
}