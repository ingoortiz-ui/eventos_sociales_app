import 'package:flutter/material.dart';

class PantallaPrueba extends StatelessWidget {
  const PantallaPrueba({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue,
      body: const Center(
        child: Text(
          'PANTALLA EXTERNA OK',
          style: TextStyle(
            fontSize: 28,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
