import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ColorPickerPopup extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorSelected;

  const ColorPickerPopup({
    super.key,
    required this.initialColor,
    required this.onColorSelected,
  });

  static Future<void> show({
    required BuildContext context,
    required Color initialColor,
    required ValueChanged<Color> onColorSelected,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => ColorPickerPopup(
        initialColor: initialColor,
        onColorSelected: onColorSelected,
      ),
    );
  }

  @override
  State<ColorPickerPopup> createState() => _ColorPickerPopupState();
}

class _ColorPickerPopupState extends State<ColorPickerPopup> {
  // Colores predeterminados de la aplicación
  static const List<Color> _defaultColors = [
    Colors.red,
    Colors.blue,
    Colors.black,
    Colors.white,
    Colors.green,
    Colors.yellow,
    Colors.orange,
    Color(0xFF5346E0),
    Colors.grey,
    Colors.pink,
  ];

  List<Color> _customColors = [];
  late Color _selectedColor;
  bool _showAdvancedPicker = false;
  final TextEditingController _hexController = TextEditingController();

  static const String _keySavedColors = 'happiley_custom_editor_colors';

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
    _updateHexText(_selectedColor);
    _loadCustomColors();
  }

  // Carga de colores personalizados guardados en persistencia local
  Future<void> _loadCustomColors() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? colorStrings = prefs.getStringList(_keySavedColors);
    if (colorStrings != null) {
      setState(() {
        _customColors = colorStrings.map((hex) {
          final buffer = StringBuffer();
          if (hex.length == 6 || hex.length == 7) buffer.write('ff');
          buffer.write(hex.replaceFirst('#', ''));
          return Color(int.parse(buffer.toString(), radix: 16));
        }).toList();
      });
    }
  }

  // Persistencia de la colección de colores personalizados
  Future<void> _saveCustomColors() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> colorStrings = _customColors.map((color) {
      return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
    }).toList();
    await prefs.setStringList(_keySavedColors, colorStrings);
  }

  // Actualización del valor hexadecimal en el campo editable
  void _updateHexText(Color color) {
    final String hex = color.value.toRadixString(16).substring(2).toUpperCase();
    _hexController.text = '#$hex';
  }

  // Procesamiento manual de código hexadecimal ingresado por el usuario
  void _onHexSubmitted(String val) {
    String cleanHex = val.trim().replaceAll('#', '');
    if (cleanHex.length == 6) {
      final intColor = int.tryParse('FF$cleanHex', radix: 16);
      if (intColor != null) {
        setState(() {
          _selectedColor = Color(intColor);
        });
      }
    }
  }

  // Aplicación inmediata y guardado del color seleccionado
  void _applyAndSaveColor() {
    if (!_customColors.contains(_selectedColor) &&
        !_defaultColors.contains(_selectedColor)) {
      _customColors.add(_selectedColor);
      _saveCustomColors();
    }
    widget.onColorSelected(_selectedColor);
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Color> allColors = [..._defaultColors, ..._customColors];

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Seleccionar Color',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Galería de círculos de colores predeterminados y personalizados
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ...allColors.map((color) {
                  final bool isSelected = _selectedColor.value == color.value;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedColor = color;
                        _updateHexText(color);
                      });
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF5346E0)
                              : Colors.grey.shade300,
                          width: isSelected ? 3.5 : 1.0,
                        ),
                      ),
                    ),
                  );
                }),
                // Botón para agregar un nuevo color personalizado
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showAdvancedPicker = !_showAdvancedPicker;
                    });
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: Icon(
                      _showAdvancedPicker ? Icons.remove : Icons.add,
                      color: const Color(0xFF5346E0),
                    ),
                  ),
                ),
              ],
            ),
            if (_showAdvancedPicker) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              // Lienzo bidimensional de selección de color y barra de luminosidad
              ColorPicker(
                pickerColor: _selectedColor,
                onColorChanged: (color) {
                  setState(() {
                    _selectedColor = color;
                    _updateHexText(color);
                  });
                },
                colorPickerWidth: 220,
                pickerAreaHeightPercent: 0.7,
                enableAlpha: false,
                displayThumbColor: true,
                paletteType: PaletteType.hsvWithHue,
                labelTypes: const [],
                pickerAreaBorderRadius: BorderRadius.circular(12),
              ),
              const SizedBox(height: 12),
              // Campo para código hexadecimal del color seleccionado
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Hex: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(
                    width: 100,
                    height: 38,
                    child: TextField(
                      controller: _hexController,
                      onSubmitted: _onHexSubmitted,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _applyAndSaveColor,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5346E0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Establecer color',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}