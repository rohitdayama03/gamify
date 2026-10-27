import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/game.dart';
import '../../providers/player_provider.dart';
import '../../widgets/game_interest_picker.dart';
import '../../widgets/primary_button.dart';

class EditInterestsScreen extends StatefulWidget {
  const EditInterestsScreen({super.key});

  @override
  State<EditInterestsScreen> createState() => _EditInterestsScreenState();
}

class _EditInterestsScreenState extends State<EditInterestsScreen> {
  late List<Game> _games;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _games = [
      ...?Provider.of<PlayerProvider>(
        context,
        listen: false,
      ).currentPlayer?.interestedGames,
    ];
  }

  Future<void> _save() async {
    final provider = Provider.of<PlayerProvider>(context, listen: false);
    final removed = (provider.currentPlayer?.interestedGames ?? const <Game>[])
        .where((g) => !_games.contains(g))
        .toList();
    if (removed.isNotEmpty && !await _confirmRemoval(removed)) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    final ok = await provider.updateInterests(_games);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(
        () => _error = provider.errorMessage ?? 'Could not save your games.',
      );
    }
  }

  Future<bool> _confirmRemoval(List<Game> removed) async {
    final names = removed.map((g) => g.shortLabel).join(' and ');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove $names?'),
        content: Text(
          '$names will no longer be one of your games. Any game profile you added stays saved and can be deleted from Profile.',
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
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your games')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.gutter),
                children: [
                  const Text(
                    'Choose the games you want to find players for. Home and Discover open on these.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  GameInterestPicker(
                    selected: _games,
                    onChanged: (games) => setState(() => _games = games),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                0,
                AppSpacing.gutter,
                AppSpacing.md,
              ),
              child: Column(
                children: [
                  if (_error != null) ...[
                    MessageBanner(message: _error!),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  PrimaryButton(
                    label: 'Save',
                    loading: _saving,
                    onPressed: _games.isEmpty ? null : _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
