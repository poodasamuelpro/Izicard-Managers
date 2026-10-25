import 'package:flutter/material.dart';

void main() => runApp(const IzicardManagersApp());

class IzicardManagersApp extends StatelessWidget {
  const IzicardManagersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Izicard Managers',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Izicard Managers')),
      body: const Center(child: Text('Bienvenue dans Izicard Managers')),
    );
  }
}
