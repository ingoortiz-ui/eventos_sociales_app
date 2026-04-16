import 'package:flutter/material.dart';

class HomeTest2 extends StatelessWidget {
  const HomeTest2({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue,
      appBar: AppBar(
        title: const Text('Home test 2'),
      ),
      body: const Center(
        child: Text(
          'HOME TEST 2 OK',
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
