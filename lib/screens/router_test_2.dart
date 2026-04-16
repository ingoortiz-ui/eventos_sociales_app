import 'package:flutter/material.dart';

class RouterTest2 extends StatelessWidget {
  const RouterTest2({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green,
      body: const Center(
        child: Text(
          'ROUTER TEST 2 OK',
          style: TextStyle(
            fontSize: 26,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
