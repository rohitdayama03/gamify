import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/game_options.dart';
import '../../models/game.dart';
import '../../providers/player_provider.dart';
import '../../widgets/primary_button.dart';

class EditGtaProfileScreen extends StatefulWidget {
  const EditGtaProfileScreen({super.key});

  @override
  State<EditGtaProfileScreen> createState() => _EditGtaProfileScreenState();
}

class _EditGtaProfileScreenState extends State<EditGtaProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _characterController = TextEditingController();
  final _rankController = TextEditingController();
  String? _platform;
  List<String> _activities = [];
  bool _submitted = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final gta = Provider.of<PlayerProvider>(
      context,
      listen: false,
    ).currentPlayer?.gtaProfile;
    if (gta != null) {
      _characterController.text = gta.characterName;
      _rankController.text = gta.rank?.toString() ?? '';
      _platform = gta.platform;
      _activities = [...gta.activities];
    }
  }

  @override
  void dispose() {
    _characterController.dispose();
    _rankController.dispose();
    super.dispose();
  }

  bool get _isEditing =>
      Provider.of<PlayerProvider>(
        context,
        listen: false,
      ).currentPlayer?.gtaProfile !=
      null;

  String? _validateRank(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final rank = int.tryParse(text);
    if (rank == null ||
        rank < GtaOptions.minRank ||
        rank > GtaOptions.maxRank) {
      return 'Enter a rank from ${GtaOptions.minRank} to ${GtaOptions.maxRank}';
    }
    return null;
  }

  Future<void> _save() async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (!_formKey.currentState!.validate() || _platform == null) return;

    final provider = Provider.of<PlayerProvider>(context, listen: false);
    setState(() => _saving = true);
    final ok = await provider.updateGtaProfile({
      'characterName': _characterController.text.trim(),
      'platform': _platform,
      // Keep the options' order so the profile reads the same way every time
      'activities': GtaOptions.activities.keys
          .where(_activities.contains)
          .toList(),
      'rank': int.tryParse(_rankController.text.trim()),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(
        () => _error =
            provider.errorMessage ?? 'Could not save your GTA Online profile.',
      );
    }
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove GTA Online profile?'),
        content: const Text(
          "Players won't be able to find you for GTA Online until you add it again.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final provider = Provider.of<PlayerProvider>(context, listen: false);
    setState(() => _saving = true);
    final ok = await provider.deleteGtaProfile();
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(
        () =>
            _error = provider.errorMessage ?? 'Could not remove your profile.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit GTA Online profile' : 'Add GTA Online profile',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: _submitted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.xs,
              AppSpacing.gutter,
              AppSpacing.lg,
            ),
            children: [
              Text(
                Game.gta.profileIntro,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _characterController,
                maxLength: 50,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Character name',
                  prefixIcon: Icon(Icons.badge_outlined),
                  helperText: 'The name other players see in GTA Online.',
                  counterText: '',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter your character name'
                    : null,
              ),
              _Section(
                title: 'Platform',
                helper: GtaOptions.platformHelp,
                error: _submitted && _platform == null
                    ? 'Choose your platform'
                    : null,
                child: Row(
                  children: [
                    for (final platform in GtaOptions.platforms) ...[
                      if (platform != GtaOptions.platforms.first)
                        const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: _PlatformOption(
                          label: platform,
                          icon: platform == 'PC'
                              ? Icons.computer_outlined
                              : Icons.sports_esports_outlined,
                          selected: platform == _platform,
                          onTap: () => setState(() => _platform = platform),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _Section(
                title: 'Preferred activities',
                helper: 'Pick everything you enjoy.',
                child: Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final MapEntry(key: activity, value: icon)
                        in GtaOptions.activities.entries)
                      FilterChip(
                        label: Text(activity),
                        avatar: Icon(
                          icon,
                          size: 18,
                          color: _activities.contains(activity)
                              ? AppColors.onPrimary
                              : AppColors.secondary,
                        ),
                        selected: _activities.contains(activity),
                        labelStyle: AppTheme.chipLabel(
                          _activities.contains(activity),
                        ),
                        showCheckmark: false,
                        onSelected: (_) => setState(() {
                          _activities = _activities.contains(activity)
                              ? _activities.where((a) => a != activity).toList()
                              : [..._activities, activity];
                        }),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _rankController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'GTA Online rank (optional)',
                  prefixIcon: Icon(Icons.military_tech_outlined),
                  helperText:
                      'From ${GtaOptions.minRank} to ${GtaOptions.maxRank}.',
                ),
                validator: _validateRank,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_error != null) ...[
                MessageBanner(message: _error!),
                const SizedBox(height: AppSpacing.md),
              ],
              PrimaryButton(
                label: 'Save GTA Online profile',
                loading: _saving,
                onPressed: _save,
              ),
              if (_isEditing) ...[
                const SizedBox(height: AppSpacing.xs),
                TextButton.icon(
                  onPressed: _saving ? null : _remove,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                  ),
                  label: const Text(
                    'Remove GTA Online profile',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String? helper;
  final String? error;
  final Widget child;

  const _Section({
    required this.title,
    this.helper,
    this.error,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          if (helper != null) ...[
            const SizedBox(height: 4),
            Text(
              helper!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          child,
          if (error != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              error!,
              style: const TextStyle(fontSize: 12.5, color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlatformOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PlatformOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: AnimatedContainer(
          duration: AppMotion.of(context, AppMotion.fast),
          height: 56,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.14)
                : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.input),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
