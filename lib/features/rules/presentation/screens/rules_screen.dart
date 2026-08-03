import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:exploding_kittens/core/theme/app_colors.dart';
import 'package:exploding_kittens/core/theme/app_text_styles.dart';
import 'package:exploding_kittens/features/game/presentation/providers/card_asset_provider.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/card_widget.dart';
import 'package:exploding_kittens/game_engine/models/card/card_type.dart';
import 'package:exploding_kittens/l10n/app_localizations.dart';

/// Explicación en criollo de las reglas ya implementadas, con las cartas de
/// verdad para que se entienda de un vistazo. No es el manual oficial del
/// juego (ver DISCLAIMER.md) — son descripciones propias de cómo se juega
/// *en esta versión*, así que si algo todavía no está soportado se aclara
/// en vez de prometerlo.
class RulesScreen extends ConsumerWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolver = ref.watch(cardAssetResolverProvider).value;
    final assetPathFor = resolver?.faceAssetFor;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onBackground,
        elevation: 0,
        title: Text(l10n.homeHowToPlay, style: AppTextStyles.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const _IntroSection(),
          const Gap(28),
          _SectionHeader(l10n.rulesSectionSpecialCards),
          const Gap(8),
          _RuleCardRow(
            type: CardType.explodingKitten,
            assetPathFor: assetPathFor,
            description: l10n.rulesExplodingKittenDesc,
          ),
          _RuleCardRow(
            type: CardType.defuse,
            assetPathFor: assetPathFor,
            description: l10n.rulesDefuseDesc,
          ),
          _RuleCardRow(
            type: CardType.nope,
            assetPathFor: assetPathFor,
            description: l10n.rulesNopeDesc,
          ),
          const Gap(20),
          _SectionHeader(l10n.rulesSectionActionCards),
          const Gap(8),
          _RuleCardRow(
            type: CardType.attack,
            assetPathFor: assetPathFor,
            description: l10n.rulesAttackDesc,
          ),
          _RuleCardRow(
            type: CardType.skip,
            assetPathFor: assetPathFor,
            description: l10n.rulesSkipDesc,
          ),
          _RuleCardRow(
            type: CardType.favor,
            assetPathFor: assetPathFor,
            description: l10n.rulesFavorDesc,
          ),
          _RuleCardRow(
            type: CardType.shuffle,
            assetPathFor: assetPathFor,
            description: l10n.rulesShuffleDesc,
          ),
          _RuleCardRow(
            type: CardType.seeTheFuture,
            assetPathFor: assetPathFor,
            description: l10n.rulesSeeTheFutureDesc,
          ),
          const Gap(20),
          _SectionHeader(l10n.rulesSectionCats),
          const Gap(8),
          const _CatCardsExplainer(),
          const Gap(8),
          _RuleCardRow(
            type: CardType.tacocat,
            assetPathFor: assetPathFor,
            description: l10n.rulesCatNeedsPairDesc,
          ),
          _RuleCardRow(
            type: CardType.rainbowRalphingCat,
            assetPathFor: assetPathFor,
            description: l10n.rulesCatNeedsPairDesc,
          ),
          _RuleCardRow(
            type: CardType.beardedDragon,
            assetPathFor: assetPathFor,
            description: l10n.rulesCatNeedsPairDesc,
          ),
          _RuleCardRow(
            type: CardType.cattermelon,
            assetPathFor: assetPathFor,
            description: l10n.rulesCatNeedsPairDesc,
          ),
          _RuleCardRow(
            type: CardType.hairyPotatoCat,
            assetPathFor: assetPathFor,
            description: l10n.rulesCatNeedsPairDesc,
          ),
        ],
      ),
    );
  }
}

class _IntroSection extends StatelessWidget {
  const _IntroSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(l10n.rulesSectionObjective),
        const Gap(6),
        Text(l10n.rulesObjectiveBody, style: AppTextStyles.body),
        const Gap(18),
        _SectionHeader(l10n.rulesSectionBeforeStart),
        const Gap(6),
        Text(l10n.rulesBeforeStartBody, style: AppTextStyles.body),
        const Gap(18),
        _SectionHeader(l10n.rulesSectionYourTurn),
        const Gap(6),
        Text(l10n.rulesYourTurnBody, style: AppTextStyles.body),
      ],
    );
  }
}

class _CatCardsExplainer extends StatelessWidget {
  const _CatCardsExplainer();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.rulesCatExplainerIntro,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const Gap(4),
          Text(
            l10n.rulesCatExplainerPairTrio,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.onBackground.withValues(alpha: 0.75),
            ),
          ),
          const Gap(4),
          Text(
            l10n.rulesCatExplainerLeftover,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.onBackground.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

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

class _RuleCardRow extends StatelessWidget {
  const _RuleCardRow({
    required this.type,
    required this.description,
    this.assetPathFor,
  });

  final CardType type;
  final String description;
  final String? Function(CardType type)? assetPathFor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardWidget(
            type: type,
            assetPath: assetPathFor?.call(type),
            width: 56,
          ),
          const Gap(14),
          Expanded(
            child: Text(
              description,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.onBackground.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
