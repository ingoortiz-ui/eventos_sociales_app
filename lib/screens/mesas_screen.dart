import 'package:flutter/material.dart';

class MesasScreen extends StatelessWidget {
  const MesasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mesas = List.generate(10, (index) => index + 1);

    return Scaffold(
      appBar: AppBar(title: const Text('Mesas')),
      body: ListView.builder(
        itemCount: mesas.length,
        itemBuilder: (context, index) {
          final mesa = mesas[index];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.table_restaurant),
              title: Text('Mesa $mesa'),
              subtitle: const Text('Capacidad: 10'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Abriste la Mesa $mesa')),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
