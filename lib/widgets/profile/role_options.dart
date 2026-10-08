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
    final code = user.code.toUpperCase().trim();

    // Determinacion del rol por texto de rol o por prefijo del codigo
    final isAdmin = (cleanRole == 'administrador' || cleanRole == 'admin') ||
        code.startsWith('AUR');
    final isSeller = cleanRole == 'vendedor' || code.startsWith('SUR');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Opciones del Sistema',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5548F5),
          ),
        ),
        const SizedBox(height: 12),

        // Opciones universales para todos los usuarios (incluye Visitante)
        _buildOptionTile(
          icon: Icons.history,
          title: 'Historial de Compras / Actividad',
          subtitle: 'Consulta tus pedidos e interacciones recientes',
          onTap: () {},
        ),
        _buildOptionTile(
          icon: Icons.favorite_border,
          title: 'Lista de Deseos',
          subtitle: 'Tus artículos guardados',
          onTap: () {},
        ),

        // Opciones exclusivas para Vendedor
        if (isSeller || isAdmin) ...[
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'Panel de Vendedor',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5548F5),
            ),
          ),
          const SizedBox(height: 8),
          _buildOptionTile(
            icon: Icons.store,
            title: 'Mis Productos',
            subtitle: 'Gestionar catálogo y stock publicado',
            onTap: () {},
          ),
          _buildOptionTile(
            icon: Icons.point_of_sale,
            title: 'Ventas Realizadas',
            subtitle: 'Revisar historial e ingresos de ventas',
            onTap: () {},
          ),
        ],

        // Opciones exclusivas para Administrador
        if (isAdmin) ...[
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'Panel de Administrador',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5548F5),
            ),
          ),
          const SizedBox(height: 8),
          _buildOptionTile(
            icon: Icons.supervisor_account,
            title: 'Gestión de Usuarios',
            subtitle: 'Administrar roles, accesos y permisos',
            onTap: () {},
          ),
          _buildOptionTile(
            icon: Icons.analytics_outlined,
            title: 'Métricas Generales',
            subtitle: 'Reportes y estadísticas globales del sistema',
            onTap: () {},
          ),
        ],
      ],
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF5548F5).withAlpha(20),
          child: Icon(icon, color: const Color(0xFF5548F5), size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Color(0xFFA0AEC0),
        ),
        onTap: onTap,
      ),
    );
  }
}