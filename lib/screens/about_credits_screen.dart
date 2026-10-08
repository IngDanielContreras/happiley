import 'package:flutter/material.dart';

class AboutCreditsScreen extends StatelessWidget {
  const AboutCreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acerca de / Créditos'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 30),

            // Logo de Happiley
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24), // Recorta la imagen para que coincida con el contenedor
                child: Image.asset(
                  'lib/assets/images/happiley_logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Happiley',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5548F5),
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'Aplicación de comercio electrónico',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF657080),
              ),
            ),

            const SizedBox(height: 32),

            const Text(
              'Créditos',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'Aplicación Desarrollada Como Proyecto Académico',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
              ),
            ),

            const SizedBox(height: 24),

            const Divider(),

            const SizedBox(height: 24),

            const Text(
              'Proyecto Desarrollado Para la Asignatura',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Diseño de Software II',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15),
              ),

            const SizedBox(height: 24),

            const Text(
              'Escuela Tecnológica Instituto Técnico Central',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15),
            ),

            const SizedBox(height: 6),

            const Text(
              'Facultad de Sistemas',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15),
            ),

            const SizedBox(height: 6),

            const Text(
              'Tecnólogo en Desarrollo de Software',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15),
            ),

            const SizedBox(height: 24),

            const Text(
              'Desarrollado por',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF657080),
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Daniel Felipe Contreras Tejedor',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}