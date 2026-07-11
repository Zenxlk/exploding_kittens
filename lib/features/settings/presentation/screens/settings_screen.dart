import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../providers/settings_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _nameController;
  bool _nameInitialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncSettings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onBackground,
        elevation: 0,
        title: Text('Ajustes', style: AppTextStyles.title),
      ),
      body: asyncSettings.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(
          child: Text('Error al cargar ajustes: $e', style: AppTextStyles.body),
        ),
        data: (settings) {
          // Sincroniza el controlador solo la primera vez o si cambió externamente
          if (!_nameInitialized) {
            _nameController.text = settings.playerName;
            _nameInitialized = true;
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            children: [
              // ── Perfil ──────────────────────────────────────────────────
              _SectionHeader('Perfil'),
              const Gap(12),

              TextField(
                controller: _nameController,
                style: AppTextStyles.body,
                maxLength: 20,
                decoration: InputDecoration(
                  labelText: 'Nombre de jugador',
                  labelStyle: AppTextStyles.caption.copyWith(
                    color: AppColors.onBackground.withValues(alpha: 0.6),
                  ),
                  prefixIcon: const Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.secondary,
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  counterStyle: AppTextStyles.caption.copyWith(
                    color: AppColors.onBackground.withValues(alpha: 0.4),
                  ),
                ),
                onSubmitted: (value) =>
                    ref.read(settingsProvider.notifier).setPlayerName(value),
                textInputAction: TextInputAction.done,
              ),

              const Gap(28),

              // ── Sonido ───────────────────────────────────────────────────
              _SectionHeader('Audio'),
              const Gap(4),

              _SettingsTile(
                title: 'Efectos de sonido',
                icon: Icons.volume_up_rounded,
                trailing: Switch(
                  value: settings.soundEnabled,
                  onChanged: (v) =>
                      ref.read(settingsProvider.notifier).setSoundEnabled(v),
                  activeThumbColor: AppColors.primary,
                  activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
                ),
              ),

              if (settings.soundEnabled) ...[
                const Gap(4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.volume_mute_rounded,
                          color: AppColors.secondary, size: 18),
                      Expanded(
                        child: Slider(
                          value: settings.volume,
                          onChanged: (v) =>
                              ref.read(settingsProvider.notifier).setVolume(v),
                        ),
                      ),
                      const Icon(Icons.volume_up_rounded,
                          color: AppColors.secondary, size: 18),
                    ],
                  ),
                ),
              ],

              const Gap(8),

              _SettingsTile(
                title: 'Música de fondo',
                icon: Icons.music_note_rounded,
                trailing: Switch(
                  value: settings.musicEnabled,
                  onChanged: (v) =>
                      ref.read(settingsProvider.notifier).setMusicEnabled(v),
                  activeThumbColor: AppColors.primary,
                  activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
                ),
              ),

              const Gap(28),

              // ── Acerca de ────────────────────────────────────────────────
              _SectionHeader('Acerca de'),
              const Gap(4),

              _SettingsTile(
                title: 'Versión',
                icon: Icons.info_outline_rounded,
                // Hardcodeado a propósito (sin package_info_plus todavía):
                // mantener sincronizado a mano con pubspec.yaml en cada
                // commit chore(version).
                trailing: Text('0.5.2',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.onBackground.withValues(alpha: 0.5),
                    )),
              ),

              _SettingsTile(
                title: 'Proyecto de fans · Sin fines comerciales',
                icon: Icons.favorite_border_rounded,
                trailing: const SizedBox.shrink(),
                subtitle:
                    'Basado en el juego original de Exploding Kittens LLC',
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: AppTextStyles.caption.copyWith(
        color: AppColors.primary,
        letterSpacing: 1.4,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    required this.icon,
    required this.trailing,
    this.subtitle,
  });

  final String title;
  final IconData icon;
  final Widget trailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, color: AppColors.secondary, size: 22),
      title: Text(title, style: AppTextStyles.body),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.onBackground.withValues(alpha: 0.45),
              ),
            )
          : null,
      trailing: trailing,
    );
  }
}
