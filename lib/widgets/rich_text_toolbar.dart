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
  bool _showFontSizeInput = false;
  final TextEditingController _fontSizeTextController =
  TextEditingController(text: '14');

  static const Color _defaultTextColor = Color(0xFF657080);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerSelectionChanged);
  }

  @override
  void didUpdateWidget(covariant RichTextToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerSelectionChanged);
      widget.controller.addListener(_onControllerSelectionChanged);
      _onControllerSelectionChanged();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerSelectionChanged);
    _fontSizeTextController.dispose();
    super.dispose();
  }

  // Deteccion automatica del tamano de fuente en la seleccion actual del texto
  void _onControllerSelectionChanged() {
    if (!mounted) return;

    final style = widget.controller.getSelectionStyle();
    final fontSizeAttr = style.attributes[Attribute.size.key];

    double newSize = 14.0;

    if (fontSizeAttr != null && fontSizeAttr.value != null) {
      final double? parsed =
      double.tryParse(fontSizeAttr.value.toString());

      if (parsed != null) {
        newSize = parsed.clamp(8.0, 50.0).toDouble();
      }
    }

    if (newSize != _fontSize) {
      setState(() {
        _fontSize = newSize;
        _fontSizeTextController.text = newSize.toInt().toString();
      });
    }
  }

  // Validacion y aplicacion del tamano de letra dentro del rango permitido (8 a 50)
  void _applyFontSize(double newSize) {
    final double clamped = newSize.clamp(8.0, 50.0).toDouble();

    setState(() {
      _fontSize = clamped;
      _fontSizeTextController.text = clamped.toInt().toString();
    });

    widget.controller.formatSelection(
      Attribute.fromKeyValue('size', clamped.toString())
      as Attribute<dynamic>,
    );
  }

  // Verificacion del estado activo del formato en el texto seleccionado
  bool _isAttributeActive(Attribute<dynamic> attribute) {
    final style = widget.controller.getSelectionStyle();
    return style.containsKey(attribute.key);
  }

  // Verificacion de la alineacion activa en el parrafo seleccionado
  bool _isAlignmentActive(Attribute<dynamic> attribute) {
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
        Attribute.clone(attribute, null) as Attribute<dynamic>,
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

    for (final Attribute<dynamic> attr in attrsToRemove) {
      widget.controller.formatSelection(
        Attribute.clone(attr, null) as Attribute<dynamic>,
      );
    }

    setState(() {
      _fontSize = 14.0;
      _fontSizeTextController.text = '14';
    });
  }

  Color _parseColor(dynamic value, Color fallback) {
    if (value is Color) {
      return value;
    }

    if (value == null) {
      return fallback;
    }

    String colorString = value.toString().trim();

    if (colorString.startsWith('#')) {
      colorString = colorString.substring(1);
    } else if (colorString.startsWith('0x')) {
      colorString = colorString.substring(2);
    }

    final int? colorValue = int.tryParse(colorString, radix: 16);

    if (colorValue == null) {
      return fallback;
    }

    if (colorString.length == 6) {
      return Color(0xFF000000 | colorValue);
    }

    if (colorString.length == 8) {
      return Color(colorValue);
    }

    return fallback;
  }

  // Apertura del modal selector de colores y aplicacion directa al texto seleccionado
  void _openColorPicker(bool isBackground) {
    final style = widget.controller.getSelectionStyle();

    final String attrKey =
    isBackground ? Attribute.background.key : Attribute.color.key;

    final Attribute<dynamic>? currentAttr = style.attributes[attrKey];

    final Color initialColor = currentAttr != null
        ? _parseColor(
      currentAttr.value,
      isBackground ? Colors.yellow : _defaultTextColor,
    )
        : (isBackground ? Colors.yellow : _defaultTextColor);

    ColorPickerPopup.show(
      context: context,
      initialColor: initialColor,
      onColorSelected: (selectedColor) {
        final String hexString =
            '#${selectedColor.value.toRadixString(16).substring(2).toUpperCase()}';

        final Attribute<dynamic> attribute = isBackground
            ? Attribute.fromKeyValue('background', hexString)
        as Attribute<dynamic>
            : Attribute.fromKeyValue('color', hexString)
        as Attribute<dynamic>;

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
        color: isActive ? Colors.grey.shade300 : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              icon,
              size: 20,
              color: isActive ? const Color(0xFF5346E0) : Colors.black87,
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
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FB),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cinta de opciones horizontal principal
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Boton para desplegar el selector de tamano de fuente
                  _buildToolbarButton(
                    icon: Icons.format_size,
                    tooltip: 'Tamaño de letra',
                    isActive: _showFontSizeInput,
                    onPressed: () {
                      setState(() {
                        _showFontSizeInput = !_showFontSizeInput;
                      });
                    },
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
                    isActive: _isAttributeActive(Attribute.color),
                    onPressed: () => _openColorPicker(false),
                  ),
                  _buildToolbarButton(
                    icon: Icons.border_color,
                    tooltip: 'Resaltador',
                    isActive: _isAttributeActive(Attribute.background),
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
                  // Botones para listas numeradas y vinetas
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
          ),

          // Campo numerico desplegable para ingresar tamano de fuente (Maximo 50)
          if (_showFontSizeInput)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool isWide = constraints.maxWidth >= 380;

                  return isWide
                      ? Row(
                    children: [
                      const Text(
                        'Tamaño (8 - 50): ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(
                        width: 50,
                        height: 34,
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
                            final double? parsed =
                            double.tryParse(val);

                            if (parsed != null) {
                              _applyFontSize(parsed);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        onPressed: () {
                          final double? parsed = double.tryParse(
                            _fontSizeTextController.text,
                          );

                          if (parsed != null) {
                            _applyFontSize(parsed);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5346E0),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          'Aplicar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3.0,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6.0,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 12.0,
                            ),
                          ),
                          child: Slider(
                            value: _fontSize,
                            min: 8.0,
                            max: 50.0,
                            activeColor: const Color(0xFF5346E0),
                            onChanged: _applyFontSize,
                          ),
                        ),
                      ),
                    ],
                  )
                      : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Tamaño (8 - 50): ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(
                            width: 50,
                            height: 34,
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
                                final double? parsed =
                                double.tryParse(val);

                                if (parsed != null) {
                                  _applyFontSize(parsed);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              final double? parsed = double.tryParse(
                                _fontSizeTextController.text,
                              );

                              if (parsed != null) {
                                _applyFontSize(parsed);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5346E0),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: const Text(
                              'Aplicar',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: double.infinity,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3.0,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6.0,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 12.0,
                            ),
                          ),
                          child: Slider(
                            value: _fontSize,
                            min: 8.0,
                            max: 50.0,
                            activeColor: const Color(0xFF5346E0),
                            onChanged: _applyFontSize,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}