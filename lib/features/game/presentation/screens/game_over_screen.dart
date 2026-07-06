import 'package:flutter/material.dart';

class GameOverScreen extends StatelessWidget {
  const GameOverScreen({super.key, required this.winnerId});

  final String winnerId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Fin de partida — ganador: $winnerId')),
    );
  }
}
