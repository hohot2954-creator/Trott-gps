import 'package:flutter/material.dart';

void main() {
  runApp(const TrottGpsApp());
}

class TrottGpsApp extends StatelessWidget {
  const TrottGpsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trott GPS',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const Scaffold(
        body: Center(
          child: Text('Trott GPS - Fonctionnel !', style: TextStyle(fontSize: 24)),
        ),
      ),
    );
  }
}
