import 'package:flutter/material.dart';
import '../../models/user.dart';

class AdminAttributes extends StatelessWidget {
  final User user;

  const AdminAttributes({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Atributos Administrativos',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5548F5),
          ),
        ),
        const SizedBox(height: 8),

        // Muestra de filas administrativas
        _buildInfoTile('Fecha de contratacion', user.hiringDate ?? 'N/A'),
        _buildInfoTile('Fecha de entrada', user.entryDate ?? 'N/A'),
        _buildInfoTile(
          'Expiracion de acceso',
          user.accessExpirationDate ?? 'N/A',
        ),
        _buildInfoTile('Fecha de terminacion', user.terminationDate ?? 'N/A'),
      ],
    );
  }

  // Construccion de fila informativa
  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}