import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/game_options.dart';
import '../models/game.dart';
import '../models/player_model.dart';
import 'game_logo.dart';
import '../core/theme/app_theme.dart';

/// Rich summary of one game profile: identity, status chips, what they want to play, key facts and their goal.
class GameProfileCard extends StatelessWidget {
  final PlayerResponse player;
  final Game game;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  // Edit actions are secondary; inviting another player is the primary purple CTA
  final bool primaryAction;

  const GameProfileCard({
    super.key,
    required this.player,
    required this.game,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.primaryAction = false,
  });

  @override
  Widget build(BuildContext context) {
    final data = _GameProfileView.of(player, game);
    if (data == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(game: game, data: data),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Divider(height: 1),
          ),
          if (data.tags.isNotEmpty) ...[
            _SectionLabel(data.tagsLabel),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final tag in data.tags)
                  _Tag(icon: tag.icon, label: tag.label),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (data.facts.isNotEmpty) _FactGrid(facts: data.facts),
          if (data.quote != null) ...[
            const SizedBox(height: AppSpacing.md),
            _Quote(text: data.quote!),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 48,
              child: primaryAction
                  ? FilledButton.icon(
                      onPressed: onAction,
                      icon: Icon(actionIcon ?? Icons.arrow_forward, size: 20),
                      label: Text(actionLabel!),
                    )
                  : OutlinedButton.icon(
                      onPressed: onAction,
                      icon: Icon(actionIcon ?? Icons.edit_outlined, size: 20),
                      label: Text(actionLabel!),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Invitation shown in place of a game profile the player hasn't added yet.
class AddGameProfileCard extends StatelessWidget {
  final Game game;
  final VoidCallback onAdd;

  const AddGameProfileCard({
    super.key,
    required this.game,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GameLogo(game: game, width: 72, height: 48),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  game.label,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            game.profileIntro,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 20),
              label: Text('Add ${game.shortLabel} profile'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Game game;
  final _GameProfileView data;

  const _Header({required this.game, required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GameLogo(
          game: game,
          width: 84,
          height: 72,
          padding: 10,
          radius: AppRadius.card,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.meta.join('  •  '),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              if (data.chips.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final chip in data.chips) _StatusChip(label: chip),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;

  const _StatusChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppFonts.label(
          fontSize: 12,
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: AppFonts.label());
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Tag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: AppColors.secondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _FactGrid extends StatelessWidget {
  final List<(String, String)> facts;

  const _FactGrid({required this.facts});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = (constraints.maxWidth - AppSpacing.md) / 2;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final (label, value) in facts)
              SizedBox(
                width: cellWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Quote extends StatelessWidget {
  final String text;

  const _Quote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.format_quote_rounded,
            color: AppColors.secondary,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Maps each game's profile fields onto the shared card layout.
class _GameProfileView {
  final String title;
  final List<String> meta;
  final List<String> chips;
  final String tagsLabel;
  final List<({IconData icon, String label})> tags;
  final List<(String, String)> facts;
  final String? quote;

  const _GameProfileView({
    required this.title,
    required this.meta,
    this.chips = const [],
    this.tagsLabel = '',
    this.tags = const [],
    this.facts = const [],
    this.quote,
  });

  static _GameProfileView? of(PlayerResponse player, Game game) {
    final languages = _text(player.language);
    final country = _text(player.country);

    switch (game) {
      case Game.gta:
        final gta = player.gtaProfile;
        if (gta == null) return null;
        return _GameProfileView(
          title: gta.characterName,
          meta: [game.shortLabel, ?country],
          chips: [if (gta.rank != null) 'Rank ${gta.rank}'],
          tagsLabel: 'Wants to play',
          tags: [
            for (final a in gta.activities)
              (icon: GtaOptions.activityIcon(a), label: a),
          ],
          facts: [
            ('Platform', gta.platform),
            if (languages != null) ('Language', languages),
          ],
        );
      case Game.bgmi:
        final bgmi = player.bgmiProfile;
        if (bgmi == null) return null;
        return _GameProfileView(
          title: bgmi.bgmiId,
          meta: [game.shortLabel, ?country],
          chips: [?_text(bgmi.currentRole)],
          tagsLabel: 'Looking for',
          tags: [
            if (_text(bgmi.lookingFor) case final v?)
              (icon: Icons.groups_outlined, label: v),
          ],
          facts: [
            if (_text(bgmi.experience) case final v?) ('Experience', v),
            if (languages != null) ('Language', languages),
            if (_text(bgmi.availableTime) case final v?) ('Availability', v),
          ],
          quote: _text(bgmi.achievements),
        );
      case Game.efootball:
        final efootball = player.efootballProfile;
        if (efootball == null) return null;
        return _GameProfileView(
          title: efootball.efootballId,
          meta: [game.shortLabel, ?country],
          chips: [?_text(efootball.highTier)],
          facts: [if (languages != null) ('Language', languages)],
        );
    }
  }

  static String? _text(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();
}
