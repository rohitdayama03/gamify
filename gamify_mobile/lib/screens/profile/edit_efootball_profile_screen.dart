import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/game.dart';
import '../../providers/player_provider.dart';
import '../../widgets/primary_button.dart';

class EditEfootballProfileScreen extends StatefulWidget {
  const EditEfootballProfileScreen({super.key});

  @override
  State<EditEfootballProfileScreen> createState() =>
      _EditEfootballProfileScreenState();
}

class _EditEfootballProfileScreenState
    extends State<EditEfootballProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  final _tierController = TextEditingController();
  bool _submitted = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final efootball = Provider.of<PlayerProvider>(
      context,
      listen: false,
    ).currentPlayer?.efootballProfile;
    if (efootball != null) {
      _nameController.text = efootball.inGameName ?? '';
      _idController.text = efootball.efootballId;
      _tierController.text = efootball.highTier ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _tierController.dispose();
    super.dispose();
  }

  bool get _isEditing =>
      Provider.of<PlayerProvider>(
        context,
        listen: false,
      ).currentPlayer?.efootballProfile !=
      null;

  Future<void> _save() async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<PlayerProvider>(context, listen: false);
    setState(() => _saving = true);
    final ok = await provider.updateEfootballProfile({
      'inGameName': _nameController.text.trim(),
      'efootballId': _idController.text.trim(),
      'highTier': _tierController.text.trim(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(
        () => _error =
            provider.errorMessage ?? 'Could not save your eFootball profile.',
      );
    }
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove eFootball profile?'),
        content: const Text(
          "Players won't be able to find you for eFootball until you add it again.",
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
    final ok = await provider.deleteEfootballProfile();
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
          _isEditing ? 'Edit eFootball profile' : 'Add eFootball profile',
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
                Game.efootball.profileIntro,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _nameController,
                maxLength: 50,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'In-game name',
                  prefixIcon: Icon(Icons.badge_outlined),
                  helperText: 'The name other players see in eFootball.',
                  counterText: '',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter your in-game name'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _idController,
                maxLength: 50,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'eFootball ID',
                  prefixIcon: Icon(Icons.tag),
                  helperText: 'Shown on your profile so players can add you.',
                  counterText: '',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter your eFootball ID'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _tierController,
                maxLength: 50,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Highest tier (optional)',
                  prefixIcon: Icon(Icons.emoji_events_outlined),
                  helperText: 'e.g. Div 1',
                  counterText: '',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_error != null) ...[
                MessageBanner(message: _error!),
                const SizedBox(height: AppSpacing.md),
              ],
              PrimaryButton(
                label: 'Save eFootball profile',
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
                    'Remove eFootball profile',
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
