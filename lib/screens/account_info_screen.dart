import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' hide SystemSoundType;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../database/user_service.dart';
import '../models/user.dart';
import '../services/system_sound_manager.dart';
import '../widgets/alert_message.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/loading_dialog.dart';
import 'image_viewer_screen.dart';

// Pantalla para consultar y editar la informacion de cuenta del usuario
class AccountInfoScreen extends StatefulWidget {
  final String userCode;

  const AccountInfoScreen({
    super.key,
    required this.userCode,
  });

  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {
  // Servicios y clave de formulario
  final UserService _userService = UserService();
  final ImagePicker _imagePicker = ImagePicker();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Controladores de los campos personales editables
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _documentNumberController =
  TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();

  // Variables de estado de carga y edicion
  User? _currentUser;
  bool _isLoading = true;
  bool _loadError = false;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _hasAnyChange = false;

  @override
  void initState() {
    super.initState();
    // Carga inicial de los datos del usuario desde la base de datos
    _fetchUser();
  }

  @override
  void dispose() {
    // Liberacion de recursos de los controladores de texto
    _firstNameController.dispose();
    _lastNameController.dispose();
    _documentNumberController.dispose();
    _emailController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  // Consulta de informacion del usuario en la base de datos
  Future<void> _fetchUser() async {
    setState(() {
      _isLoading = true;
      _loadError = false;
    });

    try {
      final User? loadedUser = await _userService.getUserById(widget.userCode);
      if (!mounted) return;

      if (loadedUser == null) {
        setState(() {
          _isLoading = false;
          _loadError = true;
        });
        return;
      }

      _syncControllersFromUser(loadedUser);
      setState(() {
        _currentUser = loadedUser;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = true;
      });
    }
  }

  // Sincronizacion de los controladores con los datos del usuario
  void _syncControllersFromUser(User user) {
    _firstNameController.text = user.firstName;
    _lastNameController.text = user.lastName;
    _documentNumberController.text = user.documentNumber;
    _emailController.text = user.email;
    _birthDateController.text = user.birthDate;
  }

  // Activacion del modo de edicion
  void _enterEditMode() {
    if (_currentUser == null) return;
    _syncControllersFromUser(_currentUser!);
    setState(() {
      _isEditing = true;
    });
  }

  // Descarte de cambios y retorno al modo de visualizacion
  void _discardChangesAndExitEditMode() {
    if (_currentUser != null) {
      _syncControllersFromUser(_currentUser!);
    }
    _formKey.currentState?.reset();
    setState(() {
      _isEditing = false;
    });
  }

  // Confirmacion mediante dialogo centralizado antes de cancelar la edicion
  void _confirmCancelEdit() {
    FocusScope.of(context).unfocus();

    AlertMessage.show(
      context: context,
      title: 'Cancelar Edición',
      message: '¿Realmente desea descartar los cambios realizados?',
      confirmText: 'Sí, cancelar',
      cancelText: 'Continuar editando',
      isConfirmDefault: false,
      onConfirm: _discardChangesAndExitEditMode,
    );
  }

  // Verificacion de ruta de recurso interno
  bool _isAssetPath(String path) {
    final String clean = path.trim();
    return clean.startsWith('lib/assets/') || clean.startsWith('assets/');
  }

  // Apertura del visor existente al pulsar la fotografia de perfil
  void _openProfileImageViewer() {
    final String? rawPath = _currentUser?.image;
    if (rawPath == null || rawPath.trim().isEmpty) return;

    final String cleanPath = rawPath.trim();
    if (!_isAssetPath(cleanPath) && !File(cleanPath).existsSync()) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageViewerScreen(imagePath: cleanPath),
      ),
    );
  }

  // Almacenamiento local y actualizacion de la fotografia en la base de datos
  Future<void> _processSelectedProfileImage(ImageSource source) async {
    final User? user = _currentUser;
    if (user == null) return;

    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 92,
      );

      if (pickedFile == null || !mounted) return;

      final File sourceFile = File(pickedFile.path);
      if (!await sourceFile.exists()) {
        throw Exception('El archivo seleccionado no se encuentra disponible.');
      }

      final Uint8List imageBytes = await sourceFile.readAsBytes();
      if (imageBytes.isEmpty) {
        throw Exception('La imagen seleccionada esta vacia o danada.');
      }

      final Directory appDir = await getApplicationDocumentsDirectory();
      final Directory profileDir = Directory(
        p.join(appDir.path, 'profile_images'),
      );

      if (!await profileDir.exists()) {
        await profileDir.create(recursive: true);
      }

      final String sanitizedCode = user.code.trim().toUpperCase();
      final String targetFileName = '${sanitizedCode}PROFILE.png';
      final String targetPath = p.join(profileDir.path, targetFileName);
      final String tempPath = p.join(
        profileDir.path,
        '${sanitizedCode}PROFILE_tmp_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      final File tempFile = File(tempPath);
      await tempFile.writeAsBytes(imageBytes, flush: true);

      if (!await tempFile.exists() || await tempFile.length() == 0) {
        throw Exception('No fue posible guardar la nueva fotografia.');
      }

      final String? previousImagePath = user.image?.trim();

      final File targetFile = File(targetPath);
      await tempFile.copy(targetPath);

      if (!await targetFile.exists() || await targetFile.length() == 0) {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
        throw Exception(
          'No fue posible consolidar la fotografia en almacenamiento.',
        );
      }

      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      await _userService.updateUserImage(user.code, targetPath);

      PaintingBinding.instance.imageCache.evict(FileImage(targetFile));

      if (previousImagePath != null &&
          previousImagePath.isNotEmpty &&
          previousImagePath != targetPath &&
          !_isAssetPath(previousImagePath)) {
        final File oldFile = File(previousImagePath);
        if (await oldFile.exists()) {
          try {
            PaintingBinding.instance.imageCache.evict(FileImage(oldFile));
            await oldFile.delete();
          } catch (_) {}
        }
      }

      final User? updatedUser = await _userService.getUserById(user.code);
      if (!mounted) return;

      setState(() {
        if (updatedUser != null) {
          _currentUser = updatedUser;
        }
        _hasAnyChange = true;
      });

      await LoadingDialog.show(
        context,
        title: '¡Fotografía Actualizada!',
        subtitle: 'Tu fotografía de perfil se guardó correctamente.',
        autoDismiss: true,
        duration: const Duration(seconds: 2),
        customSoundType: SystemSoundType.success,
        customIcon: const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF4CAF50),
          size: 56,
        ),
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      final bool isPermissionError =
          e.code == 'camera_access_denied' || e.code == 'photo_access_denied';
      await LoadingDialog.show(
        context,
        title: 'Permiso Requerido',
        subtitle: isPermissionError
            ? 'No se concedieron permisos para acceder a la cámara o galería.'
            : 'No fue posible acceder al selector de imágenes (${e.message ?? e.code}).',
        autoDismiss: true,
        duration: const Duration(seconds: 3),
        customSoundType: SystemSoundType.error,
        customIcon: const Icon(
          Icons.cancel_rounded,
          color: Color(0xFFE53935),
          size: 56,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      await LoadingDialog.show(
        context,
        title: 'Error al Actualizar Foto',
        subtitle: 'No se pudo procesar la fotografía seleccionada.',
        autoDismiss: true,
        duration: const Duration(seconds: 3),
        customSoundType: SystemSoundType.error,
        customIcon: const Icon(
          Icons.cancel_rounded,
          color: Color(0xFFE53935),
          size: 56,
        ),
      );
    }
  }

  // Menu inferior para seleccionar galeria o camara
  void _handleImagePick() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.photo_library,
                    color: Color(0xFF5548F5),
                  ),
                  title: const Text('Galería de imágenes'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _processSelectedProfileImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt,
                    color: Color(0xFF5548F5),
                  ),
                  title: const Text('Tomar foto con la cámara'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _processSelectedProfileImage(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Validacion de nombres y apellidos
  String? _validateNameField(String? value, String fieldLabel) {
    if (value == null || value.trim().isEmpty) {
      return 'El campo $fieldLabel es obligatorio.';
    }
    final String trimmed = value.trim();
    if (trimmed.length < 2) {
      return 'Ingresa al menos 2 caracteres válidos.';
    }
    final RegExp nameRegex = RegExp(r"^[a-zA-ZáéíóúÁÉÍÓÚüÜñÑ\s]+$");
    if (!nameRegex.hasMatch(trimmed)) {
      return 'Solo se permiten letras y espacios.';
    }
    return null;
  }

  // Validacion del numero de documento
  String? _validateDocumentField(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El número de documento es obligatorio.';
    }
    final String trimmed = value.trim();
    if (trimmed.length < 5 || trimmed.length > 20) {
      return 'El documento debe tener entre 5 y 20 caracteres.';
    }
    final RegExp documentRegex = RegExp(r'^[a-zA-Z0-9\-]+$');
    if (!documentRegex.hasMatch(trimmed)) {
      return 'Solo se permiten letras, números y guiones.';
    }
    return null;
  }

  // Validacion del correo electronico
  String? _validateEmailField(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El correo electrónico es obligatorio.';
    }
    final String trimmed = value.trim();
    final RegExp emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(trimmed)) {
      return 'Ingresa un correo electrónico válido (ej. usuario@dominio.com).';
    }
    return null;
  }

  // Conversion y verificacion de la fecha de nacimiento
  DateTime? _parseBirthDate(String rawDate) {
    final String trimmed = rawDate.trim();
    if (trimmed.isEmpty) return null;

    final RegExp slashDateRegex = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');
    final Match? slashMatch = slashDateRegex.firstMatch(trimmed);
    if (slashMatch != null) {
      final int day = int.parse(slashMatch.group(1)!);
      final int month = int.parse(slashMatch.group(2)!);
      final int year = int.parse(slashMatch.group(3)!);
      final DateTime candidate = DateTime(year, month, day);
      if (candidate.year == year &&
          candidate.month == month &&
          candidate.day == day) {
        return candidate;
      }
      return null;
    }

    final RegExp isoDateRegex = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
    final Match? isoMatch = isoDateRegex.firstMatch(trimmed);
    if (isoMatch != null) {
      final int year = int.parse(isoMatch.group(1)!);
      final int month = int.parse(isoMatch.group(2)!);
      final int day = int.parse(isoMatch.group(3)!);
      final DateTime candidate = DateTime(year, month, day);
      if (candidate.year == year &&
          candidate.month == month &&
          candidate.day == day) {
        return candidate;
      }
      return null;
    }

    return null;
  }

  // Validacion de la fecha de nacimiento en formato dd/MM/yyyy
  String? _validateBirthDateField(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'La fecha de nacimiento es obligatoria.';
    }
    final DateTime? parsed = _parseBirthDate(value);
    if (parsed == null) {
      return 'Usa el formato de fecha dd/MM/yyyy (ej. 04/12/2026).';
    }
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    if (parsed.isAfter(today)) {
      return 'La fecha de nacimiento no puede ser futura.';
    }
    if (parsed.year < 1900) {
      return 'Ingresa un año de nacimiento válido.';
    }
    return null;
  }

  // Selector de fecha de nacimiento con salida en formato dd/MM/yyyy
  Future<void> _selectBirthDate() async {
    final DateTime now = DateTime.now();
    final DateTime existingDate =
        _parseBirthDate(_birthDateController.text) ?? DateTime(2000, 1, 1);
    final DateTime initialDate =
    existingDate.isAfter(now) ? DateTime(2000, 1, 1) : existingDate;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF5548F5),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _birthDateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  // Validacion y confirmacion para guardar cambios
  void _confirmSaveChanges() {
    FocusScope.of(context).unfocus();

    final bool isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      LoadingDialog.show(
        context,
        title: 'Campos Incompletos o Inválidos',
        subtitle: 'Revise y complete todos los campos antes de guardar.',
        autoDismiss: true,
        duration: const Duration(seconds: 3),
        playOpenSound: false,
        customSoundType: SystemSoundType.error,
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
      title: 'Guardar Cambios',
      message: '¿Desea guardar los cambios realizados en su información?',
      confirmText: 'Sí',
      cancelText: 'No',
      isConfirmDefault: false,
      playConfirmSound: false,
      onConfirm: _executeSaveChanges,
    );
  }

  // Actualizacion de los datos personales en la base de datos
  Future<void> _executeSaveChanges() async {
    if (_currentUser == null || _isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final String newEmail = _emailController.text.trim();
      final String newDocumentNumber = _documentNumberController.text.trim();

      final bool documentTaken =
      await _userService.isDocumentNumberInUseByOtherUser(
        documentNumber: newDocumentNumber,
        currentUserCode: _currentUser!.code,
      );

      if (documentTaken) {
        if (!mounted) return;
        setState(() {
          _isSaving = false;
        });
        await LoadingDialog.show(
          context,
          title: 'Error al Actualizar',
          subtitle:
          'El número de documento ya está registrado por otro usuario.',
          autoDismiss: true,
          duration: const Duration(seconds: 3),
          customSoundType: SystemSoundType.error,
          customIcon: const Icon(
            Icons.cancel_rounded,
            color: Color(0xFFE53935),
            size: 56,
          ),
        );
        return;
      }

      final bool emailTaken = await _userService.isEmailInUseByOtherUser(
        email: newEmail,
        currentUserCode: _currentUser!.code,
      );

      if (emailTaken) {
        if (!mounted) return;
        setState(() {
          _isSaving = false;
        });
        await LoadingDialog.show(
          context,
          title: 'Error al Actualizar',
          subtitle: 'El correo electrónico ya está registrado por otro usuario.',
          autoDismiss: true,
          duration: const Duration(seconds: 3),
          customSoundType: SystemSoundType.error,
          customIcon: const Icon(
            Icons.cancel_rounded,
            color: Color(0xFFE53935),
            size: 56,
          ),
        );
        return;
      }

      final DateTime? parsedBirth = _parseBirthDate(_birthDateController.text);
      final String formattedBirthDate = parsedBirth != null
          ? DateFormat('dd/MM/yyyy').format(parsedBirth)
          : _birthDateController.text.trim();

      final bool saved = await _userService.updateUserEditableInfo(
        userCode: _currentUser!.code,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        documentNumber: newDocumentNumber,
        email: newEmail,
        birthDate: formattedBirthDate,
      );

      if (!saved) {
        throw Exception('No se pudo confirmar la actualizacion del registro.');
      }

      final User? refreshedUser =
      await _userService.getUserById(_currentUser!.code);

      if (!mounted) return;

      setState(() {
        if (refreshedUser != null) {
          _currentUser = refreshedUser;
          _syncControllersFromUser(refreshedUser);
        }
        _isEditing = false;
        _isSaving = false;
        _hasAnyChange = true;
      });

      await LoadingDialog.show(
        context,
        title: '¡Información Actualizada!',
        subtitle: 'Los cambios de tu cuenta se guardaron correctamente.',
        autoDismiss: true,
        duration: const Duration(seconds: 2),
        customSoundType: SystemSoundType.success,
        customIcon: const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF4CAF50),
          size: 56,
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      await LoadingDialog.show(
        context,
        title: 'Error al Guardar',
        subtitle: 'No fue posible actualizar tu información. Intenta nuevamente.',
        autoDismiss: true,
        duration: const Duration(seconds: 3),
        customSoundType: SystemSoundType.error,
        customIcon: const Icon(
          Icons.cancel_rounded,
          color: Color(0xFFE53935),
          size: 56,
        ),
      );
    }
  }

  // Resolucion de la imagen de perfil del usuario
  ImageProvider<Object>? _resolveUserAvatar(String? imagePath) {
    if (imagePath == null || imagePath.trim().isEmpty) return null;
    final String clean = imagePath.trim();
    if (_isAssetPath(clean)) {
      return AssetImage(clean);
    }
    final File file = File(clean);
    if (file.existsSync()) {
      return FileImage(file);
    }
    return null;
  }

  // Formateo de valores vacios para visualizacion
  String _displayValue(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'N/A';
    return raw.trim();
  }

  // Titulo de campo con indicador obligatorio o candado rojo
  Widget _buildFieldTitle(
      String label, {
        bool isRequired = false,
        bool isProtected = false,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
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
          if (isProtected) ...[
            const SizedBox(width: 6),
            const Icon(
              Icons.lock_outline,
              size: 15,
              color: Color(0xFFE53935),
            ),
          ],
        ],
      ),
    );
  }

  // Campo de solo lectura en modo visualizacion
  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required bool isProtected,
    required bool isDark,
  }) {
    final Color backgroundColor = isProtected
        ? (isDark ? const Color(0xFF232631) : const Color(0xFFECEEF3))
        : (isDark ? const Color(0xFF1C1F2A) : Colors.white);
    final Color borderColor = isProtected
        ? (isDark ? const Color(0xFF34394A) : const Color(0xFFD5DAE4))
        : (isDark ? const Color(0xFF3C4256) : const Color(0xFFE0E4EE));
    final Color textColor = isProtected
        ? (isDark ? const Color(0xFFB3BACB) : const Color(0xFF535B6E))
        : (isDark ? const Color(0xFFF1F3F9) : const Color(0xFF181B24));

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldTitle(label, isProtected: isProtected),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isProtected ? FontWeight.w500 : FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Campo de entrada habilitado en modo edicion
  Widget _buildEditableInput({
    required String label,
    required TextEditingController controller,
    required String? Function(String?) validator,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
  }) {
    final Color fillColor = isDark ? const Color(0xFF1C1F2A) : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldTitle(label, isRequired: true),
          TextFormField(
            controller: controller,
            validator: validator,
            keyboardType: keyboardType,
            readOnly: readOnly,
            onTap: onTap,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: fillColor,
              suffixIcon: suffixIcon,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(color: Color(0xFFD5DAE4)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(color: Color(0xFFD5DAE4)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(
                  color: Color(0xFF5548F5),
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(
                  color: Colors.redAccent,
                  width: 1.5,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(
                  color: Colors.red,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Campo protegido deshabilitado en modo edicion
  Widget _buildDisabledProtectedInput({
    required String label,
    required String value,
    required bool isDark,
  }) {
    final Color fillColor =
    isDark ? const Color(0xFF232631) : const Color(0xFFE5E8F0);
    final Color textColor =
    isDark ? const Color(0xFF9EA6BA) : const Color(0xFF616A7E);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldTitle(label, isProtected: true),
          TextFormField(
            initialValue: value,
            enabled: false,
            readOnly: true,
            style: TextStyle(
              fontSize: 14,
              color: textColor,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: fillColor,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: BorderSide(
                  color: isDark
                      ? const Color(0xFF34394A)
                      : const Color(0xFFCFD5E2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Lista de campos editables de la seccion Datos Personales
  List<Widget> _buildPersonalDataFields(bool isDark) {
    final User user = _currentUser!;

    return [
      if (_isEditing)
        _buildEditableInput(
          label: 'Nombres',
          controller: _firstNameController,
          validator: (val) => _validateNameField(val, 'Nombres'),
          isDark: isDark,
        )
      else
        _buildReadOnlyField(
          label: 'Nombres',
          value: _displayValue(user.firstName),
          isProtected: false,
          isDark: isDark,
        ),
      if (_isEditing)
        _buildEditableInput(
          label: 'Apellidos',
          controller: _lastNameController,
          validator: (val) => _validateNameField(val, 'Apellidos'),
          isDark: isDark,
        )
      else
        _buildReadOnlyField(
          label: 'Apellidos',
          value: _displayValue(user.lastName),
          isProtected: false,
          isDark: isDark,
        ),
      if (_isEditing)
        _buildEditableInput(
          label: 'Número de documento',
          controller: _documentNumberController,
          validator: _validateDocumentField,
          isDark: isDark,
        )
      else
        _buildReadOnlyField(
          label: 'Número de documento',
          value: _displayValue(user.documentNumber),
          isProtected: false,
          isDark: isDark,
        ),
      if (_isEditing)
        _buildEditableInput(
          label: 'Correo electrónico',
          controller: _emailController,
          validator: _validateEmailField,
          keyboardType: TextInputType.emailAddress,
          isDark: isDark,
        )
      else
        _buildReadOnlyField(
          label: 'Correo electrónico',
          value: _displayValue(user.email),
          isProtected: false,
          isDark: isDark,
        ),
      if (_isEditing)
        _buildEditableInput(
          label: 'Fecha de nacimiento',
          controller: _birthDateController,
          validator: _validateBirthDateField,
          isDark: isDark,
          suffixIcon: IconButton(
            icon: const Icon(
              Icons.calendar_month,
              color: Color(0xFF5548F5),
            ),
            onPressed: _selectBirthDate,
          ),
        )
      else
        _buildReadOnlyField(
          label: 'Fecha de nacimiento',
          value: _displayValue(user.birthDate),
          isProtected: false,
          isDark: isDark,
        ),
    ];
  }

  // Lista de campos administrados de la seccion Datos del Sistema
  List<Widget> _buildSystemDataFields(bool isDark) {
    final User user = _currentUser!;
    final bool hasAccessExpiration = user.accessExpirationDate != null &&
        user.accessExpirationDate!.trim().isNotEmpty;

    return [
      if (_isEditing)
        _buildDisabledProtectedInput(
          label: 'Código de usuario',
          value: _displayValue(user.code),
          isDark: isDark,
        )
      else
        _buildReadOnlyField(
          label: 'Código de usuario',
          value: _displayValue(user.code),
          isProtected: true,
          isDark: isDark,
        ),
      if (_isEditing)
        _buildDisabledProtectedInput(
          label: 'Rol',
          value: _displayValue(user.role),
          isDark: isDark,
        )
      else
        _buildReadOnlyField(
          label: 'Rol',
          value: _displayValue(user.role),
          isProtected: true,
          isDark: isDark,
        ),
      if (_isEditing)
        _buildDisabledProtectedInput(
          label: 'Fecha de registro',
          value: _displayValue(user.registrationDate),
          isDark: isDark,
        )
      else
        _buildReadOnlyField(
          label: 'Fecha de registro',
          value: _displayValue(user.registrationDate),
          isProtected: true,
          isDark: isDark,
        ),
      if (_isEditing)
        _buildDisabledProtectedInput(
          label: 'Fecha de contratación',
          value: _displayValue(user.hiringDate),
          isDark: isDark,
        )
      else
        _buildReadOnlyField(
          label: 'Fecha de contratación',
          value: _displayValue(user.hiringDate),
          isProtected: true,
          isDark: isDark,
        ),
      if (_isEditing)
        _buildDisabledProtectedInput(
          label: 'Fecha de ingreso',
          value: _displayValue(user.entryDate),
          isDark: isDark,
        )
      else
        _buildReadOnlyField(
          label: 'Fecha de ingreso',
          value: _displayValue(user.entryDate),
          isProtected: true,
          isDark: isDark,
        ),
      if (_isEditing)
        _buildDisabledProtectedInput(
          label: 'Último acceso',
          value: _displayValue(user.lastAccessDate),
          isDark: isDark,
        )
      else
        _buildReadOnlyField(
          label: 'Último acceso',
          value: _displayValue(user.lastAccessDate),
          isProtected: true,
          isDark: isDark,
        ),
      if (_isEditing)
        _buildDisabledProtectedInput(
          label: 'Vencimiento de contraseña',
          value: _displayValue(user.passwordExpirationDate),
          isDark: isDark,
        )
      else
        _buildReadOnlyField(
          label: 'Vencimiento de contraseña',
          value: _displayValue(user.passwordExpirationDate),
          isProtected: true,
          isDark: isDark,
        ),
      if (hasAccessExpiration) ...[
        if (_isEditing)
          _buildDisabledProtectedInput(
            label: 'Vencimiento de acceso',
            value: _displayValue(user.accessExpirationDate),
            isDark: isDark,
          )
        else
          _buildReadOnlyField(
            label: 'Vencimiento de acceso',
            value: _displayValue(user.accessExpirationDate),
            isProtected: true,
            isDark: isDark,
          ),
      ],
      if (_isEditing)
        _buildDisabledProtectedInput(
          label: 'Fecha de terminación',
          value: _displayValue(user.terminationDate),
          isDark: isDark,
        )
      else
        _buildReadOnlyField(
          label: 'Fecha de terminación',
          value: _displayValue(user.terminationDate),
          isProtected: true,
          isDark: isDark,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: !_isEditing,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && _isEditing) {
          _confirmCancelEdit();
        }
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          appBar: CustomAppBar(
            title: 'Información de Cuenta',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                if (_isEditing) {
                  _confirmCancelEdit();
                } else {
                  Navigator.of(context).pop(_hasAnyChange);
                }
              },
            ),
          ),
          body: _isLoading
              ? const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF5548F5),
            ),
          )
              : _loadError || _currentUser == null
              ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'No fue posible cargar la información de tu cuenta.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5548F5),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _fetchUser,
                    child: const Text('Volver a intentar'),
                  ),
                ],
              ),
            ),
          )
              : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Encabezado con fotografia, nombre y boton condicional en edicion
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _openProfileImageViewer,
                          child: CircleAvatar(
                            radius: 44,
                            backgroundColor: Colors.grey.shade300,
                            backgroundImage:
                            _resolveUserAvatar(_currentUser!.image),
                            child: _resolveUserAvatar(
                              _currentUser!.image,
                            ) ==
                                null
                                ? const Icon(
                              Icons.person,
                              size: 44,
                              color: Colors.white,
                            )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${_currentUser!.firstName} ${_currentUser!.lastName}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_isEditing) ...[
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed:
                            _isSaving ? null : _handleImagePick,
                            icon: const Icon(
                              Icons.camera_alt_outlined,
                              size: 18,
                            ),
                            label: const Text(
                              'Reemplazar Fotografía',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                              const Color(0xFF5548F5),
                              foregroundColor: Colors.white,
                              elevation: 1,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const Divider(height: 28),

                  // Seccion de datos personales editables
                  const Text(
                    'Datos Personales',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5548F5),
                    ),
                  ),
                  const SizedBox(height: 14),

                  ..._buildPersonalDataFields(isDark),

                  const Divider(height: 28),

                  // Seccion de datos administrados por el sistema
                  const Text(
                    'Datos en Sistema',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5548F5),
                    ),
                  ),
                  const SizedBox(height: 14),

                  ..._buildSystemDataFields(isDark),

                  const SizedBox(height: 12),

                  // Botones de accion segun el estado de la vista
                  if (!_isEditing)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _enterEditMode,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text(
                          'Editar Información de Usuario',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5548F5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                            _isSaving ? null : _confirmCancelEdit,
                            icon: const Icon(Icons.close),
                            label: const Text(
                              'Cancelar',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                              const Color(0xFF5548F5),
                              side: const BorderSide(
                                color: Color(0xFF5548F5),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isSaving
                                ? null
                                : _confirmSaveChanges,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text(
                              'Guardar',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                              const Color(0xFF5548F5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}