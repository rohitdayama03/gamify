import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/player_provider.dart';
import '../widgets/app_logo.dart';
import '../widgets/primary_button.dart';
import 'auth/welcome_screen.dart';
import 'main/main_screen.dart';
import 'onboarding/onboarding_screen.dart';

/// Decides where the app opens: Welcome when signed out, onboarding until games are chosen, otherwise Home.
class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    setState(() => _failed = false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final players = Provider.of<PlayerProvider>(context, listen: false);

    if (!await auth.checkAuthStatus()) {
      _go(const WelcomeScreen());
      return;
    }
    if (!await players.fetchMyProfile()) {
      if (players.sessionExpired) {
        await auth.logout();
        _go(const WelcomeScreen());
      } else if (mounted) {
        setState(() => _failed = true);
      }
      return;
    }
    final me = players.currentPlayer!;
    _go(me.needsOnboarding ? const OnboardingScreen() : const MainScreen());
  }

  void _go(Widget screen) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => screen,
        transitionDuration: AppMotion.of(context, AppMotion.normal),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<void> _signOut() async {
    await Provider.of<AuthProvider>(context, listen: false).logout();
    _go(const WelcomeScreen());
  }

  @override
  Widget build(BuildContext context) {
    final error = Provider.of<PlayerProvider>(context).errorMessage;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppIconImage(size: 120),
                  const SizedBox(height: AppSpacing.lg),
                  if (!_failed)
                    const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  else ...[
                    MessageBanner(
                      message: error ?? "Couldn't load your profile.",
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PrimaryButton(label: 'Try again', onPressed: _route),
                    const SizedBox(height: AppSpacing.xs),
                    TextButton(
                      onPressed: _signOut,
                      child: const Text('Sign out'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
