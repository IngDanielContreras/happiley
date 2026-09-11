import 'package:flutter/material.dart';
import '../../models/user.dart';

class RoleOptions extends StatelessWidget {
  final User user;

  const RoleOptions({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final cleanRole = user.role.toLowerCase().trim();
    final isVendor = cleanRole == 'vendedor' && user.code.startsWith('SUR');
    final isAdmin = cleanRole == 'administrador' && user.code.startsWith('AUR');

    // Retorno de vacio si no tiene rol de gestion o si es visitante
    if (!isVendor && !isAdmin) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isAdmin ? 'Opciones de Administrador' : 'Opciones de Vendedor',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5548F5),
          ),
        ),
        const SizedBox(height: 8),

        // Opciones de entrada para vendedor
        if (isVendor)
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              leading: const Icon(
                Icons.add_box_outlined,
                color: Color(0xFF5548F5),
              ),
              title: const Text('Publicar Articulo'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
              },
            ),
          ),

        // Opciones de entrada para Administrador
        if (isAdmin)
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              leading: const Icon(
                Icons.admin_panel_settings_outlined,
                color: Color(0xFF5548F5),
              ),
              title: const Text('Administrar Articulos'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
              },
            ),
          ),
      ],
    );
  }
}