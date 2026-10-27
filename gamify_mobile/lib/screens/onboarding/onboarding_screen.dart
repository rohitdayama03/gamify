import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/form_options.dart';
import '../../models/game.dart';
import '../../models/player_model.dart';
import '../../providers/player_provider.dart';
import '../../widgets/game_interest_picker.dart';
import '../../widgets/multi_select_autocomplete.dart';
import '../../widgets/primary_button.dart';
import '../main/main_screen.dart';
import '../profile/edit_game_profiles_screen.dart';
import '../../widgets/game_logo.dart';

/// First-run flow after registration: games → about you → first game profile (PRD §2, §4).
/// Each step saves when you continue, so nothing is lost if the app is closed midway.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int _stepCount = 3;
  static const String bioPlaceholder =
      'Tell other players about yourself, the games you play, and your achievements.';
  static const String bioHelper =
      'This bio will appear on your public GAMIFY profile.';
  static const List<String> _quickLanguages = [
    'English',
    'Hindi',
    'Tamil',
    'Telugu',
    'Bengali',
    'Marathi',
  ];

  final _bioController = TextEditingController();
  int _step = 0;
  List<Game> _games = [];
  List<String> _languages = [];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final me = Provider.of<PlayerProvider>(
      context,
      listen: false,
    ).currentPlayer;
    _games = [...?me?.interestedGames];
    _languages = FormOptions.splitLanguages(me?.language);
    _bioController.text = me?.playerBio ?? '';
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveAndNext(Future<bool> Function(PlayerProvider) save) async {
    final provider = Provider.of<PlayerProvider>(context, listen: false);
    setState(() {
      _saving = true;
      _error = null;
    });
    final ok = await save(provider);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) {
        _step++;
      } else {
        _error =
            provider.errorMessage ?? 'Something went wrong. Please try again.';
      }
    });
  }

  void _continueFromGames() => _saveAndNext((p) => p.updateInterests(_games));

  void _continueFromAbout() => _saveAndNext(
    (p) => p.updateProfile({
      'playerBio': _bioController.text.trim(),
      'language': FormOptions.joinLanguages(_languages),
    }),
  );

  void _finish() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const MainScreen(initialTab: MainScreen.discoverTab),
      ),
      (_) => false,
    );
  }

  void _back() => setState(() {
    _error = null;
    _step--;
  });

  void _toggleLanguage(String language) {
    setState(() {
      if (_languages.contains(language)) {
        _languages = _languages.where((l) => l != language).toList();
      } else if (_languages.length < FormOptions.maxLanguages) {
        _languages = [..._languages, language];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = Provider.of<PlayerProvider>(context).currentPlayer;

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: _step > 0
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back',
                  onPressed: _saving ? null : _back,
                )
              : null,
          title: Text(
            'Step ${_step + 1} of $_stepCount',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: (_step + 1) / _stepCount),
                  duration: AppMotion.of(context, AppMotion.normal),
                  builder: (_, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 4,
                    backgroundColor: AppColors.surfaceAlt,
                  ),
                ),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.gutter,
                        AppSpacing.lg,
                        AppSpacing.gutter,
                        AppSpacing.md,
                      ),
                      child: AnimatedSwitcher(
                        duration: AppMotion.of(context, AppMotion.normal),
                        child: KeyedSubtree(
                          key: ValueKey(_step),
                          child: _buildStep(me),
                        ),
                      ),
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
                        ..._buildActions(me),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(PlayerResponse? me) {
    switch (_step) {
      case 0:
        return _StepLayout(
          title: 'Which games do you play?',
          subtitle: 'Pick up to three. You can change this later in Settings.',
          child: GameInterestPicker(
            selected: _games,
            onChanged: (games) => setState(() => _games = games),
          ),
        );
      case 1:
        return _StepLayout(
          title: 'Tell players about you',
          subtitle: 'Optional, but players are more likely to accept requests from profiles with a bio and languages.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Languages you play in',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final language in _quickLanguages)
                    FilterChip(
                      label: Text(language),
                      selected: _languages.contains(language),
                      labelStyle: AppTheme.chipLabel(
                        _languages.contains(language),
                      ),
                      showCheckmark: true,
                      checkmarkColor: AppColors.onPrimary,
                      onSelected: (_) => _toggleLanguage(language),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // Quick-pick languages are toggled by the chips above, so this field only handles the rest
              MultiSelectAutocomplete(
                label: 'Other languages',
                options: FormOptions.languages
                    .where((l) => !_quickLanguages.contains(l))
                    .toList(),
                selected: _languages
                    .where((l) => !_quickLanguages.contains(l))
                    .toList(),
                maxSelections:
                    FormOptions.maxLanguages -
                    _languages.where(_quickLanguages.contains).length,
                onChanged: (others) => setState(() {
                  _languages = [
                    ..._languages.where(_quickLanguages.contains),
                    ...others,
                  ];
                }),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _bioController,
                minLines: 3,
                maxLines: 6,
                maxLength: 500,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  labelText: 'Bio (optional)',
                  hintText: bioPlaceholder,
                  helperText: bioHelper,
                  helperMaxLines: 2,
                  hintMaxLines: 3,
                  alignLabelWithHint: true,
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
              ),
            ],
          ),
        );
      default:
        return _StepLayout(
          title: 'Set up a game profile',
          subtitle: 'Add your in-game details so the right players can find you. You can skip this and do it later from Profile.',
          child: Column(
            children: [
              for (final game in _games) ...[
                _GameProfileSetupCard(
                  game: game,
                  done: me?.hasProfileFor(game) ?? false,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        );
    }
  }

  List<Widget> _buildActions(PlayerResponse? me) {
    switch (_step) {
      case 0:
        return [
          PrimaryButton(
            label: 'Continue',
            loading: _saving,
            onPressed: _games.isEmpty ? null : _continueFromGames,
          ),
        ];
      case 1:
        return [
          PrimaryButton(
            label: 'Continue',
            loading: _saving,
            onPressed: _continueFromAbout,
          ),
          TextButton(
            onPressed: _saving ? null : () => setState(() => _step++),
            child: const Text('Skip for now'),
          ),
        ];
      default:
        final anyDone = _games.any((g) => me?.hasProfileFor(g) ?? false);
        return [
          PrimaryButton(
            label: 'Find players',
            icon: Icons.search,
            onPressed: _finish,
          ),
          if (!anyDone)
            TextButton(onPressed: _finish, child: const Text('Skip for now')),
        ];
    }
  }
}

class _StepLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _StepLayout({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: AppSpacing.lg),
        child,
      ],
    );
  }
}

class _GameProfileSetupCard extends StatelessWidget {
  final Game game;
  final bool done;

  const _GameProfileSetupCard({required this.game, required this.done});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            GameLogo(game: game, width: 72, height: 48),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    done ? 'Profile added' : 'Not set up yet',
                    style: TextStyle(
                      fontSize: 13,
                      color: done ? AppColors.success : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            done
                ? TextButton(
                    onPressed: () => EditGameProfilesScreen.open(context, game),
                    child: const Text('Edit'),
                  )
                : FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(72, 44),
                    ),
                    onPressed: () => EditGameProfilesScreen.open(context, game),
                    child: const Text('Add'),
                  ),
          ],
        ),
      ),
    );
  }
}
