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
          color: Colors.grey,
          fontSize: 14,
        ),
      );
    }

    if (_controller == null) {
      // Soporte retrocompatible para articulos guardados en texto plano legacy
      return Text(
        widget.description,
        style: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 14,
        ),
      );
    }

    return QuillEditor.basic(
      controller: _controller!,
      config: const QuillEditorConfig(
        autoFocus: false,
        expands: false,
      ),
    );
  }
}