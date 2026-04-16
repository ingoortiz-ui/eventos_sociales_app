import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import 'home_test_2.dart';

class InitDiagScreen extends StatefulWidget {
  const InitDiagScreen({super.key});

  @override
  State<InitDiagScreen> createState() => _InitDiagScreenState();
}

class _InitDiagScreenState extends State<InitDiagScreen> {
  String status = 'Iniciando diagnóstico...';

  @override
  void initState() {
    super.initState();
    debugPrint('InitDiagScreen.initState -> ejecutandose');
    _initFirebase();
  }

  Future<void> _initFirebase() async {
    debugPrint('InitDiagScreen -> paso 1');
    setState(() {
      status = 'Paso 1: pantalla ya renderizó';
    });

    await Future.delayed(const Duration(milliseconds: 500));

    try {
      debugPrint('InitDiagScreen -> paso 2 Firebase.initializeApp');
      setState(() {
        status = 'Paso 2: intentando Firebase.initializeApp()';
      });

      if (Firebase.apps.isEmpty) {
        //  await Firebase.initializeApp(
        //  options: DefaultFirebaseOptions.currentPlatform,
        //);
      }

      debugPrint('InitDiagScreen -> paso 3 Firebase OK');
      setState(() {
        status = 'Paso 3: Firebase inicializado OK';
      });

      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;

      debugPrint('InitDiagScreen -> navegando a HomeTest2');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeTest2()),
      );
    } catch (e, st) {
      debugPrint('InitDiagScreen ERROR -> $e');
      debugPrint('$st');

      setState(() {
        status = 'ERROR Firebase: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('InitDiagScreen.build -> $status');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnóstico Firebase'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            status,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22),
          ),
        ),
      ),
    );
  }
}
