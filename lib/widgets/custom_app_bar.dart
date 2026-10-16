import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Barra superior
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final double toolbarHeight;

  const CustomAppBar({
    super.key,
    this.title,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.toolbarHeight = kToolbarHeight,
  });

  // Constructor especializado para barras invisibles de estado
  factory CustomAppBar.statusOnly() {
    return const CustomAppBar(
      toolbarHeight: 0,
      automaticallyImplyLeading: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF5548F5),
      foregroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: toolbarHeight,
      automaticallyImplyLeading: automaticallyImplyLeading,
      centerTitle: true,
      title: title != null
          ? Text(
        title!,
        style: const TextStyle(
          fontSize: 20,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      )
          : null,
      actions: actions,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF5548F5),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight);
}