
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import 'image_viewer_screen.dart';
import '../services/app_utils.dart';
import '../widgets/loading_dialog.dart';
import '../widgets/rich_text_toolbar.dart';
import '../widgets/alert_message.dart';

class PublishArticleScreen extends StatefulWidget {
  final Database? database;
  final VoidCallback? onBack;
  final VoidCallback? onArticlePublished;

  const PublishArticleScreen({
    super.key,
    this.database,
    this.onBack,
    this.onArticlePublished,
  });

  @override
  State<PublishArticleScreen> createState() =>
      _PublishArticleScreenState();
}

class _PublishArticleScreenState extends State<PublishArticleScreen> {
  final _formKey = GlobalKey<FormState>();

  Key _expansionTilesKey = UniqueKey();

  // Controladores del formulario
  final _prefixController = TextEditingController(text: 'IAR');
  final _nameController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _reorderController = TextEditingController();
  final _supportEndDateController = TextEditingController();

  // Controlador de texto enriquecido para la descripcion del articulo
  late QuillController _quillController;
  late FocusNode _descriptionFocusNode;
  late ScrollController _descriptionScrollController;

  // Previsualizacion de precio formateado en tiempo real
  String _formattedPricePreview = '';

  File? _selectedImageFile;
  final ImagePicker _picker = ImagePicker();

  bool _isHandlingBack = false;

  @override
  void initState() {
    super.initState();

    _quillController = QuillController.basic();
    _descriptionFocusNode = FocusNode();
    _descriptionScrollController = ScrollController();
  }

  @override
  void dispose() {
    _prefixController.dispose();
    _nameController.dispose();
    _quillController.dispose();
    _descriptionFocusNode.dispose();
    _descriptionScrollController.dispose();
    _salePriceController.dispose();
    _stockController.dispose();
    _reorderController.dispose();
    _supportEndDateController.dispose();
    super.dispose();
  }

  // Obtencion de la instancia de la base de datos de forma segura
  Future<Database> _getDatabase() async {
    if (widget.database != null) {
      return widget.database!;
    }

    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, 'happiley.db');

    return await openDatabase(path);
  }

  // Gestion del boton de retorno mediante la misma accion de Android
  void _handleBack() {
    if (_isHandlingBack || !mounted) return;

    _isHandlingBack = true;

    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }

    Navigator.of(context).maybePop().then((didPop) {
      if (!didPop && mounted) {
        _isHandlingBack = false;
      }
    });
  }

  // Actualizacion del formato visual de precio al escribir
  void _onPriceChanged(String value) {
    final cleanValue = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanValue.isNotEmpty) {
      final doubleParsed = double.tryParse(cleanValue);

      if (doubleParsed != null) {
        setState(() {
          _formattedPricePreview = AppUtils.formatPrice(doubleParsed);
        });
        return;
      }
    }

    setState(() {
      _formattedPricePreview = '';
    });
  }

  // Visualizacion en detalle de la imagen seleccionada
  void _openImageViewer() {
    if (_selectedImageFile == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ImageViewerScreen(imagePath: _selectedImageFile!.path),
      ),
    );
  }

  // Seleccion de la imagen del articulo
  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);

      if (pickedFile != null && mounted) {
        setState(() {
          _selectedImageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        await LoadingDialog.show(
          context,
          title: '¡Artículo No Publicado!',
          subtitle: 'Error al registrar el artículo: $e',
          autoDismiss: true,
          duration: const Duration(seconds: 5),
          customIcon: const Icon(
            Icons.cancel_rounded,
            color: Color(0xFFE53935),
            size: 56,
          ),
        );
      }
    }
  }

  // Modal selector del origen de la imagen
  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: Color(0xFF5346E0),
              ),
              title: const Text('Galería de imágenes'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.camera_alt,
                color: Color(0xFF5346E0),
              ),
              title: const Text('Tomar foto con la cámara'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Selector de la fecha de garantia o soporte
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF5346E0),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      final String formattedDate =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";

      setState(() {
        _supportEndDateController.text = formattedDate;
      });
    }
  }

  // Limpieza de campos del formulario y colapso total de tarjetas
  void _clearForm() {
    _formKey.currentState?.reset();

    _prefixController.text = 'IAR';
    _nameController.clear();
    _quillController.clear();
    _salePriceController.clear();
    _stockController.clear();
    _reorderController.clear();
    _supportEndDateController.clear();

    _descriptionFocusNode.unfocus();
    FocusScope.of(context).unfocus();

    setState(() {
      _selectedImageFile = null;
      _formattedPricePreview = '';
      _expansionTilesKey = UniqueKey();
    });
  }

  // Confirmacion antes de limpiar los campos del formulario
  Future<void> _confirmClearForm() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Limpiar Formulario'),
          content: const Text(
            '¿Estás seguro de que deseas eliminar toda la información ingresada? Esta acción no se puede deshacer.',
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
              ),
              child: const Text('Limpiar'),
            ),
            ElevatedButton(
              autofocus: true,
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5346E0),
                foregroundColor: Colors.white,
              ),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) return;

    _clearForm();
  }

  // Solicitud de confirmacion mediante alerta antes de publicar
  void _confirmPublishArticle() {
    FocusScope.of(context).unfocus();

    final bool isFormValid =
        _formKey.currentState?.validate() ?? false;

    final String plainTextDescription =
    _quillController.document.toPlainText().trim();

    if (!isFormValid ||
        _selectedImageFile == null ||
        plainTextDescription.isEmpty) {
      LoadingDialog.show(
        context,
        title: '¡Artículo No Publicado!',
        subtitle:
        'Debe completar todos los campos obligatorios, ingresar la descripción y seleccionar una imagen.',
        autoDismiss: true,
        duration: const Duration(seconds: 5),
        customIcon: const Icon(
          Icons.cancel_rounded,
          color: Color(0xFFE53935),
          size: 56,
        ),
      );
      return;
    }

    AlertMessage.show(
      context: context,
      title: 'Confirmar Publicación',
      message: '¿Desea realizar la publicación?',
      confirmText: 'Sí',
      cancelText: 'No',
      isConfirmDefault: false,
      onConfirm: _publishArticle,
    );
  }

  // Guardado en happiley.db y almacenamiento de la descripcion con texto enriquecido
  Future<void> _publishArticle() async {
    await LoadingDialog.show(
      context,
      title: 'Publicando Artículo.',
      subtitle: 'Guardando datos...',
      autoDismiss: true,
      duration: const Duration(seconds: 5),
      customIcon: const SizedBox(
        width: 40,
        height: 40,
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            Color(0xFF5346E0),
          ),
          strokeWidth: 3.5,
        ),
      ),
    );

    if (!mounted) return;

    try {
      final db = await _getDatabase();

      // Obtencion del consecutivo actual de la base de datos
      final List<Map<String, Object?>> countQuery =
      await db.rawQuery(
        'SELECT COUNT(*) AS total FROM articles',
      );

      final int totalArticles =
          Sqflite.firstIntValue(countQuery) ?? 0;

      final int consecutiveNumber = totalArticles + 1;

      if (consecutiveNumber > 999) {
        await LoadingDialog.show(
          context,
          title: '¡Artículo No Publicado!',
          subtitle:
          'Error al registrar el artículo: Se ha alcanzado el límite de novecientos noventa y nueve artículos. Amplíe la convención de nomenclatura.',
          autoDismiss: true,
          duration: const Duration(seconds: 5),
          customIcon: const Icon(
            Icons.cancel_rounded,
            color: Color(0xFFE53935),
            size: 56,
          ),
        );
        return;
      }

      // Construccion del prefijo e identificador consecutivo
      String prefix = _prefixController.text.trim().toUpperCase();

      if (prefix.length != 3) {
        prefix = 'IAR';
      }

      final String numericId =
      consecutiveNumber.toString().padLeft(3, '0');

      final String codeName = "$prefix$numericId";

      // Almacenamiento fisico de la imagen
      final Directory appDir =
      await getApplicationDocumentsDirectory();

      final Directory targetDir = Directory(
        p.join(appDir.path, 'articles_images'),
      );

      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final String fileExtension =
      p.extension(_selectedImageFile!.path).isEmpty
          ? '.png'
          : p.extension(_selectedImageFile!.path);

      final String finalFileName = "$codeName$fileExtension";

      final String internalSavedPath = p.join(
        targetDir.path,
        finalFileName,
      );

      // Copiado de archivo de imagen
      await _selectedImageFile!.copy(internalSavedPath);

      // Ruta para guardar en la base de datos
      final String relativeImagePath = internalSavedPath;

      // Insercion en la base de datos de la aplicacion
      final String todayDate =
      DateTime.now().toIso8601String().split('T')[0];

      // Sanitizacion del precio de venta para almacenar exclusivamente como valor numerico real
      final cleanPriceString =
      _salePriceController.text.trim().replaceAll(
        RegExp(r'[^0-9.]'),
        '',
      );

      final double? numericSalePrice =
      double.tryParse(cleanPriceString);

      if (numericSalePrice == null) {
        await LoadingDialog.show(
          context,
          title: '¡Artículo No Publicado!',
          subtitle: 'Error al registrar el artículo: Ingresa un precio válido.',
          autoDismiss: true,
          duration: const Duration(seconds: 5),
          customIcon: const Icon(
            Icons.cancel_rounded,
            color: Color(0xFFE53935),
            size: 56,
          ),
        );
        return;
      }

      // Serializacion del documento de texto enriquecido a JSON Delta
      final String richTextJson = jsonEncode(
        _quillController.document.toDelta().toJson(),
      );

      await db.insert('articles', {
        'code': codeName,
        'name': _nameController.text.trim(),
        'description': richTextJson,
        'purchase_price': 0.0,
        'sale_price': numericSalePrice,
        'stock': int.parse(_stockController.text.trim()),
        'purchase_date': todayDate,
        'sale_date': null,
        'units_until_reorder':
        int.parse(_reorderController.text.trim()),
        'support_end_date':
        _supportEndDateController.text.trim(),
        'image': relativeImagePath,
      });

      // Confirmacion de exito y reinicio del formulario
      if (!mounted) return;

      await LoadingDialog.show(
        context,
        title: '¡Artículo Publicado Exitosamente!',
        subtitle: 'El producto se ha guardado.',
        autoDismiss: true,
        duration: const Duration(seconds: 5),
        customIcon: const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF4CAF50),
          size: 56,
        ),
      );

      if (!mounted) return;

      _clearForm();

      if (widget.onArticlePublished != null) {
        widget.onArticlePublished!();
      } else {
        _handleBack();
      }
    } catch (e) {
      if (!mounted) return;

      await LoadingDialog.show(
        context,
        title: '¡Artículo No Publicado!',
        subtitle: 'Error al registrar el artículo: $e',
        autoDismiss: true,
        duration: const Duration(seconds: 5),
        customIcon: const Icon(
          Icons.cancel_rounded,
          color: Color(0xFFE53935),
          size: 56,
        ),
      );
    }
  }

  // Construccion de la etiqueta exterior para campos con indicador obligatorio
  Widget _buildFieldLabel(
      String labelText, {
        bool isRequired = false,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          Text(
            labelText,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          if (isRequired)
            const Text(
              ' *',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
        ],
      ),
    );
  }

  // Estrategia auxiliar para crear secciones encajonadas colapsables
  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.all(16.0),
          childrenPadding: const EdgeInsets.fromLTRB(
            16.0,
            0.0,
            16.0,
            16.0,
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF5346E0).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF5346E0),
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          subtitle: subtitle != null
              ? Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          )
              : null,
          children: [child],
        ),
      ),
    );
  }

  // Estructura comun para el diseño de las cajas de texto
  InputDecoration _inputDecoration({
    required String hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      suffixIcon: suffixIcon,
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFF5346E0),
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.5,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF5346E0);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F6FC),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: primaryColor,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
            ),
            onPressed: _handleBack,
          ),
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Publicar Nuevo Artículo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Panel de Vendedor',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: KeyedSubtree(
              key: _expansionTilesKey,
              child: Column(
                children: [
                  // Seccion de imagen del producto
                  _buildSectionCard(
                    icon: Icons.image_outlined,
                    title: 'Imagen del Producto',
                    subtitle:
                    'Selecciona una imagen desde tu galería o cámara',
                    child: Column(
                      children: [
                        if (_selectedImageFile != null) ...[
                          GestureDetector(
                            onTap: _openImageViewer,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _selectedImageFile!,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _showImageSourceDialog,
                            icon: Icon(
                              _selectedImageFile == null
                                  ? Icons.add_a_photo
                                  : Icons.refresh,
                              color: Colors.white,
                            ),
                            label: Text(
                              _selectedImageFile == null
                                  ? 'Seleccionar Imagen de la Galería / Cámara'
                                  : 'Reemplazar Imagen',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Seccion de informacion del producto
                  _buildSectionCard(
                    icon: Icons.local_offer_outlined,
                    title: 'Información del Producto',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Prefijo de Código (Opcional)'),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _prefixController,
                                maxLength: 3,
                                decoration: _inputDecoration(hint: 'Ej. IAR'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              flex: 3,
                              child: Padding(
                                padding: EdgeInsets.only(top: 8.0),
                                child: Text(
                                  'Define el prefijo de tres letras o usa IAR por defecto.',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildFieldLabel(
                          'Nombre del Artículo',
                          isRequired: true,
                        ),
                        TextFormField(
                          controller: _nameController,
                          validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Ingresa el nombre del artículo'
                              : null,
                          decoration: _inputDecoration(
                            hint: 'Ej. Teclado Mecánico RGB Switch Blue',
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildFieldLabel(
                          'Descripción del Artículo',
                          isRequired: true,
                        ),
                        // Editor de texto enriquecido con cinta de opciones de formato
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white,
                          ),
                          child: Column(
                            children: [
                              RichTextToolbar(
                                controller: _quillController,
                              ),
                              Container(
                                height: 160,
                                padding: const EdgeInsets.all(12),
                                child: QuillEditor.basic(
                                  controller: _quillController,
                                  focusNode: _descriptionFocusNode,
                                  scrollController:
                                  _descriptionScrollController,
                                  config: QuillEditorConfig(
                                    autoFocus: false,
                                    expands: false,
                                    onTapOutsideEnabled: false,
                                    placeholder:
                                    'Escribe aquí las características y especificaciones del artículo.',
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
                                      align: DefaultTextBlockStyle(
                                        const TextStyle(
                                          color: Color(0xFF616161),
                                          fontSize: 14,
                                        ),
                                        const HorizontalSpacing(0, 0),
                                        const VerticalSpacing(0, 0),
                                        const VerticalSpacing(0, 0),
                                        null,
                                      ),
                                      placeHolder: DefaultTextBlockStyle(
                                        const TextStyle(
                                          color: Color(0xFF9E9E9E),
                                          fontSize: 14,
                                        ),
                                        const HorizontalSpacing(0, 0),
                                        const VerticalSpacing(0, 0),
                                        const VerticalSpacing(0, 0),
                                        null,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Seccion de precios e inventario
                  _buildSectionCard(
                    icon: Icons.monetization_on_outlined,
                    title: 'Precios e Inventario',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel(
                                    'Precio de Venta',
                                    isRequired: true,
                                  ),
                                  TextFormField(
                                    controller: _salePriceController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    onChanged: _onPriceChanged,
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'Por favor ingresa el precio';
                                      }

                                      final cleanVal = val.replaceAll(
                                        RegExp(r'[^0-9]'),
                                        '',
                                      );

                                      if (cleanVal.isEmpty ||
                                          double.tryParse(cleanVal) == null) {
                                        return 'Ingresa un precio válido';
                                      }

                                      return null;
                                    },
                                    decoration: _inputDecoration(
                                      hint: 'Ej. 250000',
                                      suffixIcon: const Icon(
                                        Icons.attach_money,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                  if (_formattedPricePreview.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      _formattedPricePreview,
                                      style: const TextStyle(
                                        color: Color(0xFF5346E0),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel(
                                    'Stock Inicial',
                                    isRequired: true,
                                  ),
                                  TextFormField(
                                    controller: _stockController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'Requerido';
                                      }

                                      if (int.tryParse(val.trim()) == null) {
                                        return 'Inválido';
                                      }

                                      return null;
                                    },
                                    decoration: _inputDecoration(
                                      hint: 'Ej. 15',
                                      suffixIcon: const Icon(
                                        Icons.inventory_2_outlined,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildFieldLabel(
                          'Punto de reordenación',
                          isRequired: true,
                        ),
                        TextFormField(
                          controller: _reorderController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Requerido';
                            }

                            if (int.tryParse(val.trim()) == null) {
                              return 'Inválido';
                            }

                            return null;
                          },
                          decoration: _inputDecoration(
                            hint: 'Ej. 3',
                            suffixIcon: const Icon(
                              Icons.notifications_none,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Seccion de fechas y garantia
                  _buildSectionCard(
                    icon: Icons.calendar_today_outlined,
                    title: 'Fechas y Garantía',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel(
                          'Fecha fin de soporte / garantía',
                          isRequired: true,
                        ),
                        TextFormField(
                          controller: _supportEndDateController,
                          readOnly: true,
                          onTap: _selectDate,
                          validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Selecciona una fecha'
                              : null,
                          decoration: _inputDecoration(
                            hint: 'AAAA-MM-DD',
                            suffixIcon: const Icon(
                              Icons.calendar_month,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Botones de accion inferiores
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 16.0,
                      bottom: 28.0,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _confirmClearForm,
                            icon: const Icon(
                              Icons.delete_outline,
                              color: primaryColor,
                            ),
                            label: const Text(
                              'Limpiar Formulario',
                              style: TextStyle(color: primaryColor),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              side: const BorderSide(color: primaryColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _confirmPublishArticle,
                            icon: const Icon(
                              Icons.send,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Publicar Artículo',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28.0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}