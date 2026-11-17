import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' hide SystemSoundType;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../database/user_service.dart';
import '../models/user.dart';
import '../services/cart_manager.dart';
import '../services/session_manager.dart';
import '../services/system_sound_manager.dart';
import '../widgets/alert_message.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/loading_dialog.dart';
import 'image_viewer_screen.dart';
import 'main_screen.dart';

// Pantalla para consultar y editar la informacion de cuenta del usuario
class AccountInfoScreen extends StatefulWidget {
  final String userCode;
  final VoidCallback? onAccountDeleted;

  const AccountInfoScreen({
    super.key,
    required this.userCode,
    this.onAccountDeleted,
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
  Uint8List? _pendingProfileImageBytes;
  String? _pendingPreviewImagePath;
  bool _isLoading = true;
  bool _loadError = false;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isDeletingAccount = false;
  bool _hasAnyChange = false;

  @override
  void initState() {
    super.initState();
    // Carga inicial de los datos del usuario desde la base de datos
    _fetchUser();
  }

  @override
  void dispose() {
    _clearPendingProfileImage();
    // Liberacion de recursos de los controladores de texto
    _firstNameController.dispose();
    _lastNameController.dispose();
    _documentNumberController.dispose();
    _emailController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  // Apertura de conexion con la base de datos
  Future<Database> _openAppDatabase() async {
    final String databasesPath = await getDatabasesPath();
    final String dbPath = p.join(databasesPath, 'happiley.db');
    return openDatabase(dbPath);
  }

  // Eliminacion del archivo temporal de vista previa sin afectar la foto guardada
  void _clearPendingProfileImage() {
    final String? previewPath = _pendingPreviewImagePath;
    _pendingProfileImageBytes = null;
    _pendingPreviewImagePath = null;

    if (previewPath != null && previewPath.isNotEmpty) {
      try {
        final File previewFile = File(previewPath);
        if (previewFile.existsSync()) {
          PaintingBinding.instance.imageCache.evict(FileImage(previewFile));
          previewFile.deleteSync();
        }
      } catch (_) {}
    }
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
    _clearPendingProfileImage();
    _syncControllersFromUser(_currentUser!);
    setState(() {
      _isEditing = true;
    });
  }

  // Descarte de cambios y retorno al modo de visualizacion
  void _discardChangesAndExitEditMode() {
    _clearPendingProfileImage();
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
    if (_isEditing &&
        _pendingPreviewImagePath != null &&
        _pendingPreviewImagePath!.trim().isNotEmpty &&
        File(_pendingPreviewImagePath!).existsSync()) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ImageViewerScreen(imagePath: _pendingPreviewImagePath!),
        ),
      );
      return;
    }

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

  // Carga temporal de la fotografia seleccionada para vista previa previa al guardado
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

      final Directory tempDir = await getTemporaryDirectory();
      final String sanitizedCode = user.code.trim().toUpperCase();
      final String previewPath = p.join(
        tempDir.path,
        '${sanitizedCode}PROFILE_preview_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      final File previewFile = File(previewPath);
      await previewFile.writeAsBytes(imageBytes, flush: true);

      if (!await previewFile.exists() || await previewFile.length() == 0) {
        throw Exception(
          'No fue posible cargar la vista previa de la fotografia.',
        );
      }

      if (!mounted) {
        if (await previewFile.exists()) {
          await previewFile.delete();
        }
        return;
      }

      _clearPendingProfileImage();

      setState(() {
        _pendingProfileImageBytes = imageBytes;
        _pendingPreviewImagePath = previewPath;
      });

      await LoadingDialog.show(
        context,
        title: 'Fotografía Cargada',
        subtitle: 'La fotografía se ha cargado correctamente.',
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
        title: 'Error al Cargar Foto',
        subtitle: 'No se pudo cargar la fotografía seleccionada.',
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

  // Persistencia definitiva de la fotografia pendiente al confirmar el guardado
  Future<void> _persistPendingProfileImage(User user) async {
    final Uint8List? pendingBytes = _pendingProfileImageBytes;
    if (pendingBytes == null || pendingBytes.isEmpty) return;

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

    final File targetFile = File(targetPath);
    Uint8List? previousTargetBackupBytes;
    if (await targetFile.exists()) {
      previousTargetBackupBytes = await targetFile.readAsBytes();
    }

    final File tempFile = File(tempPath);
    bool targetOverwritten = false;

    try {
      await tempFile.writeAsBytes(pendingBytes, flush: true);

      if (!await tempFile.exists() || await tempFile.length() == 0) {
        throw Exception('No fue posible guardar la nueva fotografia.');
      }

      final String? previousImagePath = user.image?.trim();

      await tempFile.copy(targetPath);
      targetOverwritten = true;

      if (!await targetFile.exists() || await targetFile.length() == 0) {
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
    } catch (e) {
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      if (targetOverwritten && previousTargetBackupBytes != null) {
        try {
          await targetFile.writeAsBytes(
            previousTargetBackupBytes,
            flush: true,
          );
          PaintingBinding.instance.imageCache.evict(FileImage(targetFile));
        } catch (_) {}
      }
      rethrow;
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

  // Actualizacion de los datos personales y fotografia en la base de datos
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

      await _persistPendingProfileImage(_currentUser!);
      _clearPendingProfileImage();

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

  // Validacion de politicas de seguridad de la nueva contrasena
  String? _validateNewPasswordPolicies(String password) {
    if (password.length < 8) {
      return 'La nueva contraseña debe tener al menos 8 caracteres.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'La nueva contraseña debe incluir al menos una letra mayúscula.';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'La nueva contraseña debe incluir al menos una letra minúscula.';
    }
    if (!RegExp(r'\d').hasMatch(password)) {
      return 'La nueva contraseña debe incluir al menos un número.';
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/\\\[\];]').hasMatch(password)) {
      return 'La nueva contraseña debe incluir al menos un carácter especial.';
    }
    return null;
  }

  // Verificacion y actualizacion de la contrasena en la base de datos
  Future<String?> _verifyAndUpdatePasswordInDatabase({
    required String userCode,
    required String currentPassword,
    required String newPassword,
  }) async {
    final Database db = await _openAppDatabase();
    final rows = await db.query(
      'users',
      columns: ['password'],
      where: 'code = ?',
      whereArgs: [userCode],
      limit: 1,
    );

    if (rows.isEmpty) {
      return 'No se encontró el registro del usuario en la base de datos.';
    }

    final String storedPassword = (rows.first['password'] ?? '').toString();
    if (storedPassword != currentPassword) {
      return 'La contraseña actual ingresada es incorrecta.';
    }

    final int updatedRows = await db.update(
      'users',
      {'password': newPassword},
      where: 'code = ?',
      whereArgs: [userCode],
    );

    if (updatedRows <= 0) {
      return 'No fue posible actualizar la contraseña en la base de datos.';
    }

    return null;
  }

  // Apertura del dialogo aislado para cambiar la contrasena del usuario
  Future<void> _showChangePasswordDialog() async {
    final User? user = _currentUser;
    if (user == null || _isSaving || _isDeletingAccount) return;
    FocusScope.of(context).unfocus();

    SystemSoundManager().playDialogOpen();

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _ChangePasswordDialog(
          hostContext: context,
          userCode: user.code,
          validatePasswordPolicies: _validateNewPasswordPolicies,
          verifyAndUpdatePassword: _verifyAndUpdatePasswordInDatabase,
        );
      },
    );
  }

  // Confirmacion doble antes de eliminar la cuenta
  Future<void> _startAccountDeletionFlow() async {
    if (_isEditing ||
        _currentUser == null ||
        _isSaving ||
        _isDeletingAccount) {
      return;
    }
    FocusScope.of(context).unfocus();

    LoadingDialog.show(
      context,
      title: 'Preparando Eliminación',
      subtitle: 'Verificando el estado de tu cuenta...',
      autoDismiss: false,
      playOpenSound: true,
    );

    await Future<void>.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    SystemSoundManager().playAlert();

    final bool? firstConfirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              _AnimatedDialogIcon(
                icon: Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFE53935),
                  size: 32,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '¡Atención! Eliminación de cuenta',
                  style: TextStyle(
                    fontSize: 17.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE53935),
                  ),
                ),
              ),
            ],
          ),
          content: const SingleChildScrollView(
            child: Text(
              'Estás a punto de eliminar permanentemente tu cuenta. Esta acción eliminará toda tu información personal, preferencias, configuraciones, datos, registros de actividad y demás información asociada a tu usuario. También se eliminarán tus artículos publicados y los registros relacionados con ellos, cuando corresponda.\n\nUna vez completado el proceso, no podrás recuperar tu cuenta ni la información eliminada. Esta operación es permanente y no se puede deshacer.',
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      SystemSoundManager().playDeniedNo();
                      Navigator.of(dialogContext).pop(false);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF5548F5),
                      side: const BorderSide(color: Color(0xFF5548F5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      SystemSoundManager().playAcceptYes();
                      Navigator.of(dialogContext).pop(true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Continuar',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (!mounted || firstConfirmed != true) return;

    SystemSoundManager().playAlert();

    final bool? secondConfirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              _AnimatedDialogIcon(
                icon: Icon(
                  Icons.delete_forever_rounded,
                  color: Color(0xFFE53935),
                  size: 30,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Confirmar eliminación definitiva',
                  style: TextStyle(
                    fontSize: 17.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE53935),
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            '¿Estás completamente seguro de que deseas eliminar tu cuenta? Esta acción es irreversible y eliminará permanentemente tu usuario y toda la información asociada.',
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      SystemSoundManager().playDeniedNo();
                      Navigator.of(dialogContext).pop(false);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF5548F5),
                      side: const BorderSide(color: Color(0xFF5548F5)),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'No, conservar mi cuenta',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      SystemSoundManager().playAcceptYes();
                      Navigator.of(dialogContext).pop(true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Sí, eliminar mi cuenta',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (!mounted || secondConfirmed != true) return;

    await _executeAccountDeletion();
  }

  // Verificacion de existencia de columna en una tabla de la base de datos
  Future<bool> _tableHasColumn(
      DatabaseExecutor executor,
      String tableName,
      String columnName,
      ) async {
    final info = await executor.rawQuery('PRAGMA table_info($tableName)');
    for (final row in info) {
      if ((row['name'] ?? '').toString() == columnName) {
        return true;
      }
    }
    return false;
  }

  // Eliminacion transaccional del usuario y sus registros en la base de datos
  Future<void> _executeAccountDeletion() async {
    final User? user = _currentUser;
    if (_isEditing || user == null || _isDeletingAccount) return;

    setState(() {
      _isDeletingAccount = true;
    });

    final LoadingDialogController loadingController = LoadingDialogController();
    LoadingDialog.show(
      context,
      title: 'Eliminando Cuenta',
      subtitle:
      'Por favor, espera mientras eliminamos tu cuenta y registros asociados...',
      autoDismiss: false,
      playOpenSound: false,
      controller: loadingController,
    );

    final String userCode = user.code.trim();
    final List<String> filesToDeleteAfterCommit = [];

    try {
      final Database db = await _openAppDatabase();

      final tableRows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final existingTables = tableRows
          .map((row) => (row['name'] ?? '').toString())
          .where((name) => name.isNotEmpty)
          .toSet();

      if (user.image != null &&
          user.image!.trim().isNotEmpty &&
          !_isAssetPath(user.image!)) {
        filesToDeleteAfterCommit.add(user.image!.trim());
      }

      await db.transaction((Transaction txn) async {
        // Consulta de ruta de imagen registrada en la tabla de usuarios
        if (existingTables.contains('users')) {
          final bool hasImageCol =
          await _tableHasColumn(txn, 'users', 'image');
          final bool hasCodeCol = await _tableHasColumn(txn, 'users', 'code');
          if (hasImageCol && hasCodeCol) {
            final userRows = await txn.query(
              'users',
              columns: ['image'],
              where: 'code = ?',
              whereArgs: [userCode],
            );
            for (final row in userRows) {
              final String img = (row['image'] ?? '').toString().trim();
              if (img.isNotEmpty && !_isAssetPath(img)) {
                filesToDeleteAfterCommit.add(img);
              }
            }
          }
        }

        // Eliminacion de articulos vinculados al usuario si existe columna de propietario
        if (existingTables.contains('articles')) {
          const possibleOwnerColumns = [
            'seller_code',
            'user_code',
            'owner_code',
            'created_by',
          ];
          String? ownerColumn;
          for (final String candidate in possibleOwnerColumns) {
            if (await _tableHasColumn(txn, 'articles', candidate)) {
              ownerColumn = candidate;
              break;
            }
          }

          if (ownerColumn != null) {
            final ownedArticles = await txn.query(
              'articles',
              where: '$ownerColumn = ?',
              whereArgs: [userCode],
            );

            for (final article in ownedArticles) {
              final String imgPath =
              (article['image'] ?? '').toString().trim();
              if (imgPath.isNotEmpty && !_isAssetPath(imgPath)) {
                final sharedRefs = await txn.query(
                  'articles',
                  columns: ['image'],
                  where: 'image = ? AND $ownerColumn != ?',
                  whereArgs: [imgPath, userCode],
                  limit: 1,
                );
                if (sharedRefs.isEmpty) {
                  filesToDeleteAfterCommit.add(imgPath);
                }
              }
            }

            await txn.delete(
              'articles',
              where: '$ownerColumn = ?',
              whereArgs: [userCode],
            );
          }
        }

        // Eliminacion de compras e items asociados exclusivamente al usuario
        if (existingTables.contains('purchases')) {
          const possibleBuyerColumns = [
            'user_code',
            'buyer_code',
            'customer_code',
          ];
          String? buyerColumn;
          for (final String candidate in possibleBuyerColumns) {
            if (await _tableHasColumn(txn, 'purchases', candidate)) {
              buyerColumn = candidate;
              break;
            }
          }

          if (buyerColumn != null) {
            if (existingTables.contains('purchase_items') &&
                await _tableHasColumn(txn, 'purchases', 'id') &&
                await _tableHasColumn(txn, 'purchase_items', 'purchase_id')) {
              final userPurchases = await txn.query(
                'purchases',
                columns: ['id'],
                where: '$buyerColumn = ?',
                whereArgs: [userCode],
              );
              for (final purchase in userPurchases) {
                final Object? purchaseId = purchase['id'];
                if (purchaseId != null) {
                  await txn.delete(
                    'purchase_items',
                    where: 'purchase_id = ?',
                    whereArgs: [purchaseId],
                  );
                }
              }
            }

            await txn.delete(
              'purchases',
              where: '$buyerColumn = ?',
              whereArgs: [userCode],
            );
          }
        }

        // Eliminacion de notificaciones y registros de actividad del usuario
        if (existingTables.contains('notifications') &&
            await _tableHasColumn(txn, 'notifications', 'user_code')) {
          await txn.delete(
            'notifications',
            where: 'user_code = ?',
            whereArgs: [userCode],
          );
        }

        // Eliminacion de registros en otras tablas vinculadas por codigo de usuario
        const handledTables = {
          'users',
          'articles',
          'purchases',
          'purchase_items',
          'notifications',
          'sqlite_sequence',
          'android_metadata',
        };
        for (final String tableName in existingTables) {
          if (handledTables.contains(tableName)) continue;
          if (await _tableHasColumn(txn, tableName, 'user_code')) {
            await txn.delete(
              tableName,
              where: 'user_code = ?',
              whereArgs: [userCode],
            );
          }
        }

        // Eliminacion definitiva del registro principal del usuario
        final int deletedUsers = await txn.delete(
          'users',
          where: 'code = ?',
          whereArgs: [userCode],
        );

        if (deletedUsers <= 0) {
          throw Exception('No se pudo eliminar el registro del usuario.');
        }
      });

      // Eliminacion de archivos e imagenes asociados tras confirmar la transaccion
      _clearPendingProfileImage();
      for (final String rawFilePath in filesToDeleteAfterCommit.toSet()) {
        try {
          final File targetFile = File(rawFilePath);
          if (await targetFile.exists()) {
            PaintingBinding.instance.imageCache.evict(FileImage(targetFile));
            await targetFile.delete();
          }
        } catch (_) {}
      }

      try {
        final Directory appDir = await getApplicationDocumentsDirectory();
        final Directory profileDir = Directory(
          p.join(appDir.path, 'profile_images'),
        );
        if (await profileDir.exists()) {
          final String prefix = '${userCode.toUpperCase()}PROFILE';
          await for (final FileSystemEntity entity in profileDir.list()) {
            if (entity is File &&
                p.basename(entity.path).toUpperCase().startsWith(prefix)) {
              try {
                PaintingBinding.instance.imageCache.evict(FileImage(entity));
                await entity.delete();
              } catch (_) {}
            }
          }
        }
      } catch (_) {}

      if (!mounted) return;

      await loadingController.showResult(
        title: 'Cuenta Eliminada Correctamente',
        subtitle:
        'Tu cuenta y toda tu información asociada han sido eliminadas permanentemente.',
        isSuccess: true,
        duration: const Duration(seconds: 4),
      );

      // Limpieza de estados del carrito y de la sesion activa igual que en cierre de sesion
      CartManager.clearCart();
      SessionManager.clearSession();

      try {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        for (final String key in prefs.getKeys().toList()) {
          final String lowerKey = key.toLowerCase();
          if (lowerKey.contains('active_user') ||
              lowerKey.contains('activeuser') ||
              lowerKey.contains('user_code') ||
              lowerKey.contains('usercode') ||
              lowerKey.contains(userCode.toLowerCase())) {
            await prefs.remove(key);
          }
        }
      } catch (_) {}

      if (!mounted) return;

      final NavigatorState navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop('account_deleted');
        widget.onAccountDeleted?.call();
      } else {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (BuildContext context) => MainScreen(
              database: db,
              initialIndex: 3,
            ),
          ),
              (Route<dynamic> route) => false,
        );
      }
    } catch (_) {
      if (!mounted) return;

      await loadingController.showResult(
        title: 'No se Pudo Eliminar la Cuenta',
        subtitle:
        'Ocurrió un error al completar la eliminación. Tu sesión y tus datos se conservan sin cambios.',
        isSuccess: false,
        duration: const Duration(seconds: 4),
      );

      if (!mounted) return;
      setState(() {
        _isDeletingAccount = false;
      });
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

  // Tarjeta desplegable reutilizable para organizar las secciones de cuenta
  Widget _buildExpandableSection({
    required String title,
    required bool initiallyExpanded,
    required bool isDark,
    required List<Widget> children,
  }) {
    final Color cardColor = isDark ? const Color(0xFF1C1F2A) : Colors.white;
    final Color borderColor =
    isDark ? const Color(0xFF34394A) : const Color(0xFFE0E4EE);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          maintainState: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          iconColor: const Color(0xFF5548F5),
          collapsedIconColor: const Color(0xFF5548F5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5548F5),
            ),
          ),
          children: children,
        ),
      ),
    );
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

  // Lista de campos editables de la seccion Datos del Perfil
  List<Widget> _buildProfileDataFields(bool isDark) {
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
      if (!_isEditing) ...[
        const SizedBox(height: 2),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: (_isSaving || _isDeletingAccount)
                ? null
                : _showChangePasswordDialog,
            icon: const Icon(Icons.lock_reset_rounded),
            label: const Text(
              'Cambiar contraseña',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF5548F5),
              side: const BorderSide(
                color: Color(0xFF5548F5),
              ),
              padding: const EdgeInsets.symmetric(
                vertical: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
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
      if (!_isEditing) ...[
        const SizedBox(height: 2),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: (_isSaving || _isDeletingAccount)
                ? null
                : _startAccountDeletionFlow,
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text(
              'Eliminar cuenta',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFE53935),
              backgroundColor: const Color(0xFFE53935).withValues(
                alpha: isDark ? 0.14 : 0.06,
              ),
              side: const BorderSide(
                color: Color(0xFFE53935),
              ),
              padding: const EdgeInsets.symmetric(
                vertical: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final ImageProvider<Object>? avatarProvider = _currentUser == null
        ? null
        : (_isEditing && _pendingProfileImageBytes != null
        ? MemoryImage(_pendingProfileImageBytes!)
        : _resolveUserAvatar(_currentUser!.image));

    return PopScope(
      canPop: !_isEditing && !_isDeletingAccount,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && _isEditing && !_isDeletingAccount) {
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
              onPressed: _isDeletingAccount
                  ? null
                  : () {
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
                            backgroundImage: avatarProvider,
                            child: avatarProvider == null
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
                              'Reemplazar fotografía',
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

                  const SizedBox(height: 20),

                  // Lista desplegable de Datos del Perfil expandida por defecto
                  _buildExpandableSection(
                    title: 'Datos del Perfil',
                    initiallyExpanded: true,
                    isDark: isDark,
                    children: _buildProfileDataFields(isDark),
                  ),

                  const SizedBox(height: 16),

                  // Lista desplegable de Datos del Sistema contraida por defecto
                  _buildExpandableSection(
                    title: 'Datos en Sistema',
                    initiallyExpanded: false,
                    isDark: isDark,
                    children: _buildSystemDataFields(isDark),
                  ),

                  const SizedBox(height: 20),

                  // Botones de accion segun el estado de la vista
                  if (!_isEditing)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isDeletingAccount
                            ? null
                            : _enterEditMode,
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

// Animacion exclusiva para el icono interior de los dialogos de alerta
class _AnimatedDialogIcon extends StatefulWidget {
  final Widget icon;

  const _AnimatedDialogIcon({required this.icon});

  @override
  State<_AnimatedDialogIcon> createState() => _AnimatedDialogIconState();
}

class _AnimatedDialogIconState extends State<_AnimatedDialogIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: widget.icon,
    );
  }
}

// Dialogo independiente con validacion individual por campo para cambiar contrasena
class _ChangePasswordDialog extends StatefulWidget {
  final BuildContext hostContext;
  final String userCode;
  final String? Function(String password) validatePasswordPolicies;
  final Future<String?> Function({
  required String userCode,
  required String currentPassword,
  required String newPassword,
  }) verifyAndUpdatePassword;

  const _ChangePasswordDialog({
    required this.hostContext,
    required this.userCode,
    required this.validatePasswordPolicies,
    required this.verifyAndUpdatePassword,
  });

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final TextEditingController _currentPasswordController =
  TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
  TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;

  String? _currentPasswordError;
  String? _newPasswordError;
  String? _confirmPasswordError;

  static const Duration _loadingDisplayDuration = Duration(seconds: 2);

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Evaluacion individual de cada campo del formulario
  bool _validateIndividualFields() {
    final String currentPassword = _currentPasswordController.text;
    final String newPassword = _newPasswordController.text;
    final String confirmPassword = _confirmPasswordController.text;

    String? currentError;
    String? newError;
    String? confirmError;

    if (currentPassword.isEmpty) {
      currentError = 'Ingresa tu contraseña actual.';
    }

    if (newPassword.isEmpty) {
      newError = 'Ingresa la nueva contraseña.';
    } else {
      final String? policyError = widget.validatePasswordPolicies(newPassword);
      if (policyError != null) {
        newError = policyError;
      } else if (currentPassword.isNotEmpty &&
          newPassword == currentPassword) {
        newError = 'La nueva contraseña debe ser diferente a la actual.';
      }
    }

    if (confirmPassword.isEmpty) {
      confirmError = 'Confirma tu nueva contraseña.';
    } else if (newPassword != confirmPassword) {
      confirmError = 'Las contraseñas nuevas no coinciden.';
    }

    setState(() {
      _currentPasswordError = currentError;
      _newPasswordError = newError;
      _confirmPasswordError = confirmError;
    });

    return currentError == null && newError == null && confirmError == null;
  }

  // Decoracion visual con tonalidad roja suavizada exclusivamente en campos con error
  InputDecoration _buildPasswordFieldDecoration({
    required String labelText,
    required IconData prefixIconData,
    required bool isObscured,
    required VoidCallback onToggleObscure,
    required String? errorText,
    required bool isDark,
  }) {
    final bool hasError = errorText != null;
    final Color softErrorStroke =
    isDark ? const Color(0xFFD67A7A) : const Color(0xFFC86D6D);
    final Color softErrorText =
    isDark ? const Color(0xFFE08C8C) : const Color(0xFFB45353);
    final Color activeColor =
    hasError ? softErrorStroke : const Color(0xFF5548F5);

    return InputDecoration(
      labelText: labelText,
      labelStyle: hasError
          ? TextStyle(
        color: softErrorText,
        fontWeight: FontWeight.w500,
      )
          : null,
      filled: hasError,
      fillColor: hasError
          ? softErrorStroke.withValues(alpha: isDark ? 0.08 : 0.04)
          : null,
      errorText: errorText,
      errorMaxLines: 3,
      errorStyle: TextStyle(
        color: softErrorText,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(
        prefixIconData,
        color: activeColor,
      ),
      suffixIcon: IconButton(
        icon: Icon(
          isObscured
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: hasError ? softErrorStroke : null,
        ),
        onPressed: onToggleObscure,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD5DAE4)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD5DAE4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFF5548F5),
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: softErrorStroke,
          width: 1.2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: softErrorStroke,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _buildRequirementItem({
    required String text,
    required bool isMet,
    required bool isDark,
  }) {
    final Color metColor =
    isDark ? const Color(0xFF66BB6A) : const Color(0xFF2E8B57);
    final Color pendingIconColor =
    isDark ? const Color(0xFF7D869C) : const Color(0xFF949EB0);
    final Color textColor = isMet
        ? (isDark ? const Color(0xFFE6EAF4) : const Color(0xFF232834))
        : (isDark ? const Color(0xFFABB3C7) : const Color(0xFF5D677A));

    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1.5),
            child: Icon(
              isMet
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 14.5,
              color: isMet ? metColor : pendingIconColor,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.3,
                fontWeight: isMet ? FontWeight.w600 : FontWeight.w400,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordRequirementsCard(bool isDark) {
    final String currentPassword = _currentPasswordController.text;
    final String newPassword = _newPasswordController.text;
    final String confirmPassword = _confirmPasswordController.text;

    final bool hasMinLength = newPassword.length >= 8;
    final bool hasUppercase = RegExp(r'[A-Z]').hasMatch(newPassword);
    final bool hasLowercase = RegExp(r'[a-z]').hasMatch(newPassword);
    final bool hasNumber = RegExp(r'\d').hasMatch(newPassword);
    final bool hasSpecialChar =
    RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/\\\[\];]').hasMatch(newPassword);
    final bool isDifferentFromCurrent =
        newPassword.isNotEmpty && newPassword != currentPassword;
    final bool matchesConfirmation =
        newPassword.isNotEmpty && newPassword == confirmPassword;

    final Color containerColor =
    isDark ? const Color(0xFF232735) : const Color(0xFFF6F7FB);
    final Color borderColor =
    isDark ? const Color(0xFF343A4E) : const Color(0xFFE1E5F0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 15.5,
                color: Color(0xFF5548F5),
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Requisitos de la nueva contraseña',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF5548F5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          _buildRequirementItem(
            text: 'Mínimo 8 caracteres de longitud',
            isMet: hasMinLength,
            isDark: isDark,
          ),
          _buildRequirementItem(
            text: 'Al menos una letra mayúscula (A-Z)',
            isMet: hasUppercase,
            isDark: isDark,
          ),
          _buildRequirementItem(
            text: 'Al menos una letra minúscula (a-z)',
            isMet: hasLowercase,
            isDark: isDark,
          ),
          _buildRequirementItem(
            text: 'Al menos un número (0-9)',
            isMet: hasNumber,
            isDark: isDark,
          ),
          _buildRequirementItem(
            text: 'Al menos un carácter especial (!@#\$%^&*...)',
            isMet: hasSpecialChar,
            isDark: isDark,
          ),
          _buildRequirementItem(
            text: 'Diferente a tu contraseña actual',
            isMet: isDifferentFromCurrent,
            isDark: isDark,
          ),
          _buildRequirementItem(
            text: 'Coincidir con la confirmación de contraseña',
            isMet: matchesConfirmation,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  // Ejecucion controlada de validacion y actualizacion en base de datos
  Future<void> _handleConfirmPressed() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();

    if (!_validateIndividualFields()) {
      SystemSoundManager().playError();
      return;
    }

    final String currentPassword = _currentPasswordController.text;
    final String newPassword = _newPasswordController.text;

    setState(() {
      _isSubmitting = true;
    });

    final LoadingDialogController loadingController = LoadingDialogController();
    LoadingDialog.show(
      widget.hostContext,
      title: 'Procesando Cambio',
      subtitle: 'Validando datos y actualizando contraseña...',
      autoDismiss: false,
      playOpenSound: false,
      controller: loadingController,
      customIcon: const SizedBox(
        width: 40,
        height: 40,
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5548F5)),
          strokeWidth: 3.5,
        ),
      ),
    );

    final Future<void> minimumLoadingDelay =
    Future<void>.delayed(_loadingDisplayDuration);

    try {
      final List<Object?> results = await Future.wait<Object?>([
        widget.verifyAndUpdatePassword(
          userCode: widget.userCode,
          currentPassword: currentPassword,
          newPassword: newPassword,
        ),
        minimumLoadingDelay,
      ]);
      final String? updateError = results[0] as String?;

      if (updateError != null) {
        await loadingController.showResult(
          title: 'No se Pudo Actualizar',
          subtitle: updateError,
          isSuccess: false,
          duration: const Duration(seconds: 3),
        );
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
          if (updateError.toLowerCase().contains('contraseña actual')) {
            _currentPasswordError = updateError;
          }
        });
        return;
      }

      await loadingController.showResult(
        title: '¡Contraseña Actualizada!',
        subtitle: 'Tu contraseña se actualizó correctamente.',
        isSuccess: true,
        duration: const Duration(seconds: 3),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      await minimumLoadingDelay;
      await loadingController.showResult(
        title: 'Error al Actualizar',
        subtitle:
        'Ocurrió un error al actualizar la contraseña en la base de datos.',
        isSuccess: false,
        duration: const Duration(seconds: 3),
      );
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: const Row(
        children: [
          _AnimatedDialogIcon(
            icon: Icon(
              Icons.lock_reset_rounded,
              color: Color(0xFF5548F5),
              size: 26,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Cambiar Contraseña',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ingresa tu contraseña actual y define una nueva contraseña segura.',
              style: TextStyle(
                fontSize: 13.5,
                color: Color(0xFF657080),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _currentPasswordController,
              obscureText: _obscureCurrent,
              enabled: !_isSubmitting,
              autofocus: false,
              onChanged: (_) {
                setState(() {
                  if (_currentPasswordError != null) {
                    _currentPasswordError = null;
                  }
                });
              },
              decoration: _buildPasswordFieldDecoration(
                labelText: 'Contraseña actual',
                prefixIconData: Icons.lock_outline,
                isObscured: _obscureCurrent,
                onToggleObscure: () {
                  setState(() {
                    _obscureCurrent = !_obscureCurrent;
                  });
                },
                errorText: _currentPasswordError,
                isDark: isDark,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _newPasswordController,
              obscureText: _obscureNew,
              enabled: !_isSubmitting,
              autofocus: false,
              onChanged: (_) {
                setState(() {
                  if (_newPasswordError != null ||
                      _confirmPasswordError != null) {
                    _newPasswordError = null;
                    _confirmPasswordError = null;
                  }
                });
              },
              decoration: _buildPasswordFieldDecoration(
                labelText: 'Nueva contraseña',
                prefixIconData: Icons.vpn_key_outlined,
                isObscured: _obscureNew,
                onToggleObscure: () {
                  setState(() {
                    _obscureNew = !_obscureNew;
                  });
                },
                errorText: _newPasswordError,
                isDark: isDark,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              enabled: !_isSubmitting,
              autofocus: false,
              onChanged: (_) {
                setState(() {
                  if (_confirmPasswordError != null) {
                    _confirmPasswordError = null;
                  }
                });
              },
              decoration: _buildPasswordFieldDecoration(
                labelText: 'Confirmar nueva contraseña',
                prefixIconData: Icons.check_circle_outline,
                isObscured: _obscureConfirm,
                onToggleObscure: () {
                  setState(() {
                    _obscureConfirm = !_obscureConfirm;
                  });
                },
                errorText: _confirmPasswordError,
                isDark: isDark,
              ),
            ),
            const SizedBox(height: 14),
            _buildPasswordRequirementsCard(isDark),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
      actions: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                autofocus: true,
                onPressed: _isSubmitting
                    ? null
                    : () {
                  SystemSoundManager().playDeniedNo();
                  Navigator.of(context).pop(false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5548F5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                autofocus: false,
                onPressed: _isSubmitting ? null : _handleConfirmPressed,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF5548F5),
                  side: const BorderSide(color: Color(0xFF5548F5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Confirmar',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}