import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/form_options.dart';
import '../core/theme/app_theme.dart';
import '../models/game.dart';
import '../models/player_model.dart';
import 'player_avatar.dart';

/// The account-level identity block at the top of a profile. It is deliberately not a bordered card
/// (game profiles below are), so the person reads separately from their per-game details:
/// round avatar, big name, a stats strip, bio, languages and one action.
class PlayerHeader extends StatelessWidget {
  static const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  final PlayerResponse player;
  // e.g. Edit profile on your own page, the request/message button on someone else's
  final Widget? action;
  final String emptyBioText;
  // Set on your own profile: tapping the picture changes it
  final VoidCallback? onAvatarTap;
  // While a new picture is saving
  final bool avatarBusy;

  const PlayerHeader({
    super.key,
    required this.player,
    this.action,
    this.emptyBioText = 'No bio yet.',
    this.onAvatarTap,
    this.avatarBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    final bio = player.playerBio?.trim() ?? '';
    final languages = FormOptions.splitLanguages(player.language);
    final gameCount = Game.values.where(player.hasProfileFor).length;
    final joined = player.createdAt == null ? '—' : '${_months[player.createdAt!.month - 1]} ${player.createdAt!.year % 100}';

    return Container(
      // A faint mint wash fading into the page, instead of a card outline
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primary.withValues(alpha: 0.08), AppColors.background.withValues(alpha: 0)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.lg, AppSpacing.gutter, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _RoundAvatar(name: player.username, url: player.avatarUrl, onTap: onAvatarTap, busy: avatarBusy),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PLAYER${player.country?.isNotEmpty == true ? '  //  ${player.country!.toUpperCase()}' : ''}', style: AppFonts.label(color: AppColors.primary)),
                    const SizedBox(height: 4),
                    Text(
                      player.username,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _StatsStrip(stats: [
            ('$gameCount', gameCount == 1 ? 'Game' : 'Games'),
            ('${languages.length}', languages.length == 1 ? 'Language' : 'Languages'),
            (joined, 'Joined'),
          ]),
          const SizedBox(height: AppSpacing.md),
          Text(
            bio.isEmpty ? emptyBioText : bio,
            style: bio.isEmpty
                ? const TextStyle(color: AppColors.textSecondary, fontStyle: FontStyle.italic, height: 1.45)
                : const TextStyle(fontSize: 15, height: 1.5),
          ),
          if (languages.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final language in languages) _LanguageTag(language)],
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: AppSpacing.md),
            action!,
          ],
        ],
      ),
    );
  }
}

class _RoundAvatar extends StatelessWidget {
  final String name;
  final String? url;
  final VoidCallback? onTap;
  final bool busy;

  const _RoundAvatar({required this.name, this.url, this.onTap, this.busy = false});

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: 76,
      height: 76,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.primary, width: 2)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          PlayerAvatar(
            name: name,
            url: url,
            radius: 35,
            textStyle: TextStyle(fontFamily: AppFonts.display, fontSize: 30, fontWeight: FontWeight.w700, color: AppColors.primary),
          ),
          if (busy)
            const DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black54),
              child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
        ],
      ),
    );
    if (onTap == null) return avatar;
    return Semantics(
      button: true,
      label: 'Change profile picture',
      child: GestureDetector(
        onTap: busy ? null : onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            avatar,
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  border: Border.all(color: AppColors.background, width: 2),
                ),
                child: const Icon(Icons.photo_camera, size: 14, color: AppColors.onPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three numbers separated by hairlines, like a terminal readout
class _StatsStrip extends StatelessWidget {
  final List<(String, String)> stats;

  const _StatsStrip({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border), bottom: BorderSide(color: AppColors.border)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < stats.length; i++) ...[
              if (i > 0) const VerticalDivider(width: 1, color: AppColors.border),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stats[i].$1, style: TextStyle(fontFamily: AppFonts.display, fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(stats[i].$2.toUpperCase(), style: AppFonts.label(fontSize: 10.5)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LanguageTag extends StatelessWidget {
  final String language;

  const _LanguageTag(this.language);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.translate, size: 14, color: AppColors.secondary),
          const SizedBox(width: 6),
          Text(language, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
