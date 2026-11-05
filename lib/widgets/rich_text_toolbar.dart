import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'color_picker_popup.dart';

class RichTextToolbar extends StatefulWidget {
  final QuillController controller;

  const RichTextToolbar({
    super.key,
    required this.controller,
  });

  @override
  State<RichTextToolbar> createState() => _RichTextToolbarState();
}

class _RichTextToolbarState extends State<RichTextToolbar> {
  double _fontSize = 14.0;

  final TextEditingController _fontSizeTextController =
  TextEditingController(text: '14');

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerSelectionChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerSelectionChanged);
    _fontSizeTextController.dispose();
    super.dispose();
  }

  // Deteccion automatica del tamaño de fuente en la seleccion actual del texto
  void _onControllerSelectionChanged() {
    final style = widget.controller.getSelectionStyle();
    final fontSizeAttr = style.attributes[Attribute.size.key];

    if (fontSizeAttr != null && fontSizeAttr.value != null) {
      final double? parsed =
      double.tryParse(fontSizeAttr.value.toString());

      if (parsed != null && parsed != _fontSize) {
        setState(() {
          _fontSize = parsed;
          _fontSizeTextController.text = parsed.toInt().toString();
        });
      }
    }
  }

  // Actualizacion bidireccional del tamaño de letra mediante el campo numerico o la barra deslizante
  void _applyFontSize(double newSize) {
    final double clamped = newSize.clamp(8.0, 48.0);

    setState(() {
      _fontSize = clamped;
      _fontSizeTextController.text = clamped.toInt().toString();
    });

    widget.controller.formatSelection(
      Attribute.fromKeyValue('size', clamped.toString()),
    );
  }

  // Verificacion del estado activo del formato en el texto seleccionado
  bool _isAttributeActive(Attribute attribute) {
    final style = widget.controller.getSelectionStyle();
    return style.containsKey(attribute.key);
  }

  // Verificacion de la alineacion activa en el parrafo seleccionado
  bool _isAlignmentActive(Attribute attribute) {
    final style = widget.controller.getSelectionStyle();
    final attr = style.attributes[Attribute.align.key];

    if (attr == null) {
      return attribute.value == null;
    }

    return attr.value == attribute.value;
  }

  // Alternancia de formatos tipograficos en el texto seleccionado
  void _toggleAttribute(Attribute<dynamic> attribute) {
    final bool isActive = _isAttributeActive(attribute);

    if (isActive) {
      widget.controller.formatSelection(
        Attribute.clone(attribute, null),
      );
    } else {
      widget.controller.formatSelection(attribute);
    }

    setState(() {});
  }

  // Alternancia de alineaciones de parrafo en la seleccion actual
  void _toggleAlignment(Attribute<dynamic> attribute) {
    widget.controller.formatSelection(attribute);
    setState(() {});
  }

  // Restablecimiento de estilos tipograficos conservando la estructura de parrafos y listas
  void _resetFormatting() {
    final List<Attribute<dynamic>> attrsToRemove = [
      Attribute.bold,
      Attribute.italic,
      Attribute.underline,
      Attribute.strikeThrough,
      Attribute.color,
      Attribute.background,
      Attribute.size,
    ];

    for (final attr in attrsToRemove) {
      widget.controller.formatSelection(
        Attribute.clone(attr, null),
      );
    }

    setState(() {});
  }

  // Apertura del modal selector de colores para texto o fondo de resaltado
  void _openColorPicker(bool isBackground) {
    final style = widget.controller.getSelectionStyle();

    final attrKey = isBackground
        ? Attribute.background.key
        : Attribute.color.key;

    final currentAttr = style.attributes[attrKey];

    Color initialColor =
    isBackground ? Colors.yellow : Colors.black;

    if (currentAttr != null && currentAttr.value != null) {
      final String hex =
      currentAttr.value.toString().replaceAll('#', '');

      final int? intColor = int.tryParse('FF$hex', radix: 16);

      if (intColor != null) {
        initialColor = Color(intColor);
      }
    }

    ColorPickerPopup.show(
      context: context,
      initialColor: initialColor,
      onColorSelected: (selectedColor) {
        final String hexString =
            '#${selectedColor.value.toRadixString(16).substring(2).toUpperCase()}';

        final attribute = isBackground
            ? Attribute.background
            : Attribute.color;

        widget.controller.formatSelection(
          Attribute.fromKeyValue(attribute.key, hexString),
        );

        widget.controller.formatSelection(attribute);
        setState(() {});
      },
    );
  }

  // Construccion de boton de formato con soporte de estado activo e indicador informativo tooltip
  Widget _buildToolbarButton({
    required IconData icon,
    required String tooltip,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isActive
            ? Colors.grey.shade300
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              icon,
              size: 20,
              color: isActive
                  ? const Color(0xFF5346E0)
                  : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canUndo = widget.controller.hasUndo;
    final bool canRedo = widget.controller.hasRedo;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FB),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(12),
        ),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Controladores de tamaño de letra con campo numerico y barra deslizante
            Tooltip(
              message: 'Tamaño de letra',
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 32,
                    child: TextField(
                      controller: _fontSizeTextController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onSubmitted: (val) {
                        final double? parsed = double.tryParse(val);

                        if (parsed != null) {
                          _applyFontSize(parsed);
                        }
                      },
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: Slider(
                      value: _fontSize,
                      min: 8.0,
                      max: 48.0,
                      divisions: 40,
                      activeColor: const Color(0xFF5346E0),
                      onChanged: _applyFontSize,
                    ),
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 16),

            // Botones de estilo tipografico
            _buildToolbarButton(
              icon: Icons.format_bold,
              tooltip: 'Negrilla',
              isActive: _isAttributeActive(Attribute.bold),
              onPressed: () => _toggleAttribute(Attribute.bold),
            ),
            _buildToolbarButton(
              icon: Icons.format_italic,
              tooltip: 'Cursiva',
              isActive: _isAttributeActive(Attribute.italic),
              onPressed: () => _toggleAttribute(Attribute.italic),
            ),
            _buildToolbarButton(
              icon: Icons.format_underlined,
              tooltip: 'Subrayado',
              isActive: _isAttributeActive(Attribute.underline),
              onPressed: () => _toggleAttribute(Attribute.underline),
            ),
            _buildToolbarButton(
              icon: Icons.strikethrough_s,
              tooltip: 'Tachado',
              isActive: _isAttributeActive(Attribute.strikeThrough),
              onPressed: () =>
                  _toggleAttribute(Attribute.strikeThrough),
            ),
            const VerticalDivider(width: 16),

            // Botones para eleccion de color de letra y resaltado de texto
            _buildToolbarButton(
              icon: Icons.format_color_text,
              tooltip: 'Color de letra',
              isActive: false,
              onPressed: () => _openColorPicker(false),
            ),
            _buildToolbarButton(
              icon: Icons.border_color,
              tooltip: 'Resaltador',
              isActive: false,
              onPressed: () => _openColorPicker(true),
            ),
            const VerticalDivider(width: 16),

            // Botones de alineacion de parrafos
            _buildToolbarButton(
              icon: Icons.format_align_left,
              tooltip: 'Alinear a la izquierda',
              isActive: _isAlignmentActive(Attribute.leftAlignment),
              onPressed: () =>
                  _toggleAlignment(Attribute.leftAlignment),
            ),
            _buildToolbarButton(
              icon: Icons.format_align_center,
              tooltip: 'Centrar',
              isActive: _isAlignmentActive(Attribute.centerAlignment),
              onPressed: () =>
                  _toggleAlignment(Attribute.centerAlignment),
            ),
            _buildToolbarButton(
              icon: Icons.format_align_right,
              tooltip: 'Alinear a la derecha',
              isActive: _isAlignmentActive(Attribute.rightAlignment),
              onPressed: () =>
                  _toggleAlignment(Attribute.rightAlignment),
            ),
            _buildToolbarButton(
              icon: Icons.format_align_justify,
              tooltip: 'Justificar',
              isActive: _isAlignmentActive(Attribute.justifyAlignment),
              onPressed: () =>
                  _toggleAlignment(Attribute.justifyAlignment),
            ),
            const VerticalDivider(width: 16),

            // Botones para listas numeradas y viñetas
            _buildToolbarButton(
              icon: Icons.format_list_bulleted,
              tooltip: 'Viñetas',
              isActive: _isAttributeActive(Attribute.ul),
              onPressed: () => _toggleAttribute(Attribute.ul),
            ),
            _buildToolbarButton(
              icon: Icons.format_list_numbered,
              tooltip: 'Numeración',
              isActive: _isAttributeActive(Attribute.ol),
              onPressed: () => _toggleAttribute(Attribute.ol),
            ),
            const VerticalDivider(width: 16),

            // Botones del historial de operaciones Deshacer y Rehacer
            Tooltip(
              message: 'Deshacer',
              child: IconButton(
                icon: const Icon(Icons.undo),
                iconSize: 20,
                color: canUndo
                    ? const Color(0xFF5346E0)
                    : Colors.grey.shade400,
                onPressed: canUndo
                    ? () {
                  widget.controller.undo();
                  setState(() {});
                }
                    : null,
              ),
            ),
            Tooltip(
              message: 'Rehacer',
              child: IconButton(
                icon: const Icon(Icons.redo),
                iconSize: 20,
                color: canRedo
                    ? const Color(0xFF5346E0)
                    : Colors.grey.shade400,
                onPressed: canRedo
                    ? () {
                  widget.controller.redo();
                  setState(() {});
                }
                    : null,
              ),
            ),
            const VerticalDivider(width: 16),

            // Boton para restablecer el formato tipografico a texto plano conservando la estructura
            _buildToolbarButton(
              icon: Icons.format_clear,
              tooltip: 'Restablecer formato',
              isActive: false,
              onPressed: _resetFormatting,
            ),
          ],
        ),
      ),
    );
  }
}