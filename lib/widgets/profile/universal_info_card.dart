import 'package:flutter/material.dart';
import '../../models/user.dart';

class UniversalInfoCard extends StatelessWidget {
  final User user;

  const UniversalInfoCard({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Informacion de la Cuenta',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5548F5),
          ),
        ),
        const SizedBox(height: 8),

        // Muestra de filas informativas
        _buildInfoTile('Codigo unico', user.code),
        _buildInfoTile('Documento', user.documentNumber),
        _buildInfoTile('Correo electronico', user.email),
        _buildInfoTile('Fecha de registro', user.registrationDate),
        _buildInfoTile(
          'Expiracion de contraseña',
          user.passwordExpirationDate,
        ),
      ],
    );
  }

  // Construccion de fila informativa de lectura
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