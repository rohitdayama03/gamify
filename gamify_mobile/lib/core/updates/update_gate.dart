import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/app_logo.dart';
import '../../widgets/primary_button.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../constants/app_colors.dart';

/// Checks for a newer version on Google Play when the app opens and when it comes back to the foreground.
///
/// Below the server's minimum version the app is blocked by Play's full-screen update, with an
/// "update required" screen behind it if the player backs out. Otherwise, a newer version gets Play's
/// background download at most once a day, and a "Restart" snackbar once it's ready.
///
/// Only works for installs from Google Play; elsewhere (debug builds, iOS, web) it does nothing.
class UpdateGate extends StatefulWidget {
  final Widget child;

  const UpdateGate({super.key, required this.child});

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> with WidgetsBindingObserver {
  static const _promptedAtKey = 'update_prompted_at';
  static const _promptEvery = Duration(days: 1);

  final _storage = const FlutterSecureStorage();
  bool _required = false;
  bool _checking = false;
  bool _flexibleStarted = false;

  bool get _supported => !kIsWeb && Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    if (!_supported) return;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Coming back from Play (or from the background) may mean they updated, or backed out of a required update
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    try {
      final required = await _belowMinimum();
      if (mounted && required != _required) setState(() => _required = required);

      final AppUpdateInfo info = await InAppUpdate.checkForUpdate();
      if (required) {
        // Also resumes an update Play was already installing when the app was closed
        final available = info.updateAvailability == UpdateAvailability.updateAvailable ||
            info.updateAvailability == UpdateAvailability.developerTriggeredUpdateInProgress;
        if (available && info.immediateUpdateAllowed) await InAppUpdate.performImmediateUpdate();
        return;
      }
      if (info.installStatus == InstallStatus.downloaded) {
        _offerRestart();
        return;
      }
      if (info.updateAvailability == UpdateAvailability.updateAvailable &&
          info.flexibleUpdateAllowed &&
          !_flexibleStarted &&
          await _duePrompt()) {
        _flexibleStarted = true;
        await _storage.write(key: _promptedAtKey, value: DateTime.now().toIso8601String());
        // Completes once the download finishes, while the player carries on using the app
        final result = await InAppUpdate.startFlexibleUpdate();
        if (result == AppUpdateResult.success) _offerRestart();
      }
    } catch (_) {
      // Not installed from Play, no network, or the server is unreachable: carry on without updating
    } finally {
      _checking = false;
    }
  }

  // A failed lookup never blocks the app
  Future<bool> _belowMinimum() async {
    try {
      final response = await ApiClient().dio.get(ApiEndpoints.appVersion);
      final min = (response.data['minAndroidVersionCode'] as num?)?.toInt() ?? 0;
      final current = int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;
      return current > 0 && current < min;
    } catch (_) {
      return _required;
    }
  }

  Future<bool> _duePrompt() async {
    final last = DateTime.tryParse(await _storage.read(key: _promptedAtKey) ?? '');
    return last == null || DateTime.now().difference(last) >= _promptEvery;
  }

  void _offerRestart() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('A new version of GAMIFY is ready'),
        duration: const Duration(days: 1),
        action: SnackBarAction(label: 'Restart', onPressed: InAppUpdate.completeFlexibleUpdate),
      ),
    );
  }

  Future<void> _updateNow() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable && info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
        return;
      }
    } catch (_) {
      // Fall through to the store page
    }
    final packageName = (await PackageInfo.fromPlatform()).packageName;
    await launchUrl(
      Uri.parse('https://play.google.com/store/apps/details?id=$packageName'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_required) return widget.child;
    return _UpdateRequiredScreen(onUpdate: _updateNow);
  }
}

class _UpdateRequiredScreen extends StatelessWidget {
  final Future<void> Function() onUpdate;

  const _UpdateRequiredScreen({required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: AppLogo(size: 64)),
              const SizedBox(height: AppSpacing.lg),
              Text('Update required', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'This version of GAMIFY is no longer supported. Update to keep playing.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(label: 'Update now', icon: Icons.system_update, onPressed: onUpdate),
            ],
          ),
        ),
      ),
    );
  }
}
