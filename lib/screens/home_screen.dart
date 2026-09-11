import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'about_credits_screen.dart';
import 'main_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HomeContent(
        onExplore: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MainScreen(
                initialIndex: 1,
              ),
            ),
          );
        },
      ),
    );
  }
}

class HomeContent extends StatelessWidget {
  final VoidCallback onExplore;

  const HomeContent({
    super.key,
    required this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFF5548F5),
              ),
              child: Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48),

                  const Text(
                    'Happiley',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.notifications_none,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Contenido con márgenes
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                children: [
                  const SizedBox(height: 28),

                  // Welcome card
                  Container(
                    width: double.infinity,
                    height: 285,
                    decoration: BoxDecoration(
                      borderRadius:
                      BorderRadius.circular(26),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFF4F8FF),
                          Color(0xFFEAF1FC),
                        ],
                      ),
                      border: Border.all(
                        color: const Color(0xFFE1E5EB),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 22,
                          left: 22,
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color:
                              const Color(0xFF5548F5),
                              borderRadius:
                              BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.shopping_bag_outlined,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),

                        Positioned(
                          top: 80,
                          right: 25,
                          child: Icon(
                            Icons.devices_outlined,
                            size: 105,
                            color: Colors.white
                                .withValues(alpha: 0.75),
                          ),
                        ),

                        Positioned(
                          bottom: 25,
                          left: 22,
                          right: 22,
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: const [
                              Text(
                                '¡Bienvenido a\nHappiley!',
                                style: TextStyle(
                                  fontSize: 28,
                                  height: 1.05,
                                  fontWeight:
                                  FontWeight.bold,
                                  color:
                                  Color(0xFF101522),
                                ),
                              ),

                              SizedBox(height: 12),

                              Text(
                                'Tu destino para lo mejor en tecnología',
                                style: TextStyle(
                                  fontSize: 14,
                                  color:
                                  Color(0xFF657080),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Main button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: onExplore,
                      style: FilledButton.styleFrom(
                        backgroundColor:
                        const Color(0xFF5548F5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(28),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment:
                        MainAxisAlignment.center,
                        children: [
                          Text(
                            'Ingresar a la Tienda',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 10),
                          Icon(
                            Icons.arrow_forward,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Credits button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                            const AboutCreditsScreen(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                        const Color(0xFF101522),
                        side: const BorderSide(
                          color: Color(0xFFE0E3E8),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(28),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment:
                        MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Acerca de / Créditos',
                            style: TextStyle(
                              fontWeight:
                              FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Close application
                  TextButton(
                    onPressed: () {
                      SystemNavigator.pop();
                    },
                    child: const Text(
                      'Cerrar Aplicación',
                      style: TextStyle(
                        color: Color(0xFF515A6A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}