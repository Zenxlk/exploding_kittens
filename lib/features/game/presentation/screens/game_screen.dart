import 'package:flutter/material.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Partida')),
      body: const Center(child: Text('Pantalla de juego — Fase 4')),
    );
  }
}
