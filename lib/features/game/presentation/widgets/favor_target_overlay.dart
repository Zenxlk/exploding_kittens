import 'package:flutter/material.dart';

import 'package:exploding_kittens/core/theme/app_colors.dart';
import 'package:exploding_kittens/core/theme/app_text_styles.dart';
import 'package:exploding_kittens/game_engine/models/player/player_model.dart';

/// Selector de jugador objetivo para Favor y pares de gato (ambos solo
/// necesitan un objetivo; el trío de gatos necesita además elegir una carta
/// concreta de la mano del rival y llega en un paso aparte). Widget "tonto".
class FavorTargetOverlay extends StatelessWidget {
  const FavorTargetOverlay({
    super.key,
    required this.candidates,
    required this.onSelect,
    required this.onCancel,
  });

  final List<PlayerModel> candidates;
  final ValueChanged<String> onSelect;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Elige a quién pedirle una carta', style: AppTextStyles.title),
            const SizedBox(height: 16),
            for (final player in candidates)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: SizedBox(
                  width: 220,
                  child: OutlinedButton(
                    onPressed: () => onSelect(player.id),
                    child: Text(player.name),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}
