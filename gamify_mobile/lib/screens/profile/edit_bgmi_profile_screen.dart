import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/game.dart';
import '../../providers/player_provider.dart';
import '../../widgets/primary_button.dart';

class EditBgmiProfileScreen extends StatefulWidget {
  const EditBgmiProfileScreen({super.key});

  @override
  State<EditBgmiProfileScreen> createState() => _EditBgmiProfileScreenState();
}

class _EditBgmiProfileScreenState extends State<EditBgmiProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  final _roleController = TextEditingController();
  // Whole years played; null means not given, 0 means under a year
  int? _experienceYears;
  TimeOfDay? _availableFrom;
  TimeOfDay? _availableTo;
  final _lookingForController = TextEditingController();
  final _achievementsController = TextEditingController();
  bool _submitted = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final bgmi = Provider.of<PlayerProvider>(
      context,
      listen: false,
    ).currentPlayer?.bgmiProfile;
    if (bgmi != null) {
      _nameController.text = bgmi.inGameName ?? '';
      _idController.text = bgmi.bgmiId;
      _roleController.text = bgmi.currentRole ?? '';
      _experienceYears = _parseYears(bgmi.experience);
      final times = _timePattern
          .allMatches(bgmi.availableTime ?? '')
          .map(_toTimeOfDay)
          .toList();
      if (times.length == 2) {
        _availableFrom = times[0];
        _availableTo = times[1];
      }
      _lookingForController.text = bgmi.lookingFor ?? '';
      _achievementsController.text = bgmi.achievements ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameController,
      _idController,
      _roleController,
      _lookingForController,
      _achievementsController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  static const int _maxYears = 20;

  // Matches times saved by this screen ("8:00 PM") and typed before it had a picker ("8 PM")
  static final _timePattern = RegExp(
    r'(\d{1,2})(?::(\d{2}))?\s*([AP]M)',
    caseSensitive: false,
  );

  static TimeOfDay _toTimeOfDay(RegExpMatch m) {
    final hour = int.parse(m[1]!) % 12;
    final pm = m[3]!.toUpperCase() == 'PM';
    return TimeOfDay(
      hour: pm ? hour + 12 : hour,
      minute: int.parse(m[2] ?? '0'),
    );
  }

  static int? _parseYears(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (value.toLowerCase().contains('under')) return 0;
    final years = int.tryParse(RegExp(r'\d+').firstMatch(value)?[0] ?? '');
    return years?.clamp(0, _maxYears);
  }

  static String _yearsLabel(int years) => switch (years) {
    0 => 'Under 1 year',
    1 => '1 year',
    _ => '$years years',
  };

  // Always written as "8:00 PM" so it can be read back into the picker
  static String _formatTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
  }

  String get _availableTime => _availableFrom == null || _availableTo == null
      ? ''
      : '${_formatTime(_availableFrom!)} - ${_formatTime(_availableTo!)}';

  Future<void> _pickTime({required bool from}) async {
    final picked = await showTimePicker(
      context: context,
      helpText: from ? 'AVAILABLE FROM' : 'AVAILABLE UNTIL',
      initialTime:
          (from ? _availableFrom : _availableTo) ??
          (from
              ? const TimeOfDay(hour: 20, minute: 0)
              : const TimeOfDay(hour: 23, minute: 0)),
    );
    if (picked == null) return;
    setState(() => from ? _availableFrom = picked : _availableTo = picked);
  }

  bool get _isEditing =>
      Provider.of<PlayerProvider>(
        context,
        listen: false,
      ).currentPlayer?.bgmiProfile !=
      null;

  Future<void> _save() async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (!_formKey.currentState!.validate()) return;
    if ((_availableFrom == null) != (_availableTo == null)) {
      setState(() => _error = 'Choose both a start and an end time.');
      return;
    }

    final provider = Provider.of<PlayerProvider>(context, listen: false);
    setState(() => _saving = true);
    final ok = await provider.updateBgmiProfile({
      'inGameName': _nameController.text.trim(),
      'bgmiId': _idController.text.trim(),
      'currentRole': _roleController.text.trim(),
      'experience': _experienceYears == null
          ? ''
          : _yearsLabel(_experienceYears!),
      'availableTime': _availableTime,
      'lookingFor': _lookingForController.text.trim(),
      'achievements': _achievementsController.text.trim(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(
        () => _error =
            provider.errorMessage ?? 'Could not save your BGMI profile.',
      );
    }
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove BGMI profile?'),
        content: const Text(
          "Players won't be able to find you for BGMI until you add it again.",
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
    final ok = await provider.deleteBgmiProfile();
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
        title: Text(_isEditing ? 'Edit BGMI profile' : 'Add BGMI profile'),
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
                Game.bgmi.profileIntro,
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
                  helperText: 'The name other players see in BGMI.',
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
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'BGMI ID',
                  prefixIcon: Icon(Icons.tag),
                  helperText: 'Shown on your profile so players can add you.',
                  counterText: '',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter your BGMI ID'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _roleController,
                maxLength: 50,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Role (optional)',
                  prefixIcon: Icon(Icons.shield_outlined),
                  helperText: 'e.g. IGL, Assaulter, Sniper',
                  counterText: '',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _FieldLabel(
                title: 'Experience (optional)',
                helper: 'How long you have played BGMI.',
              ),
              _ExperienceStepper(
                years: _experienceYears,
                maxYears: _maxYears,
                label: _experienceYears == null
                    ? 'Not set'
                    : _yearsLabel(_experienceYears!),
                onChanged: (years) => setState(() => _experienceYears = years),
              ),
              const SizedBox(height: AppSpacing.lg),
              _FieldLabel(
                title: 'Available time (optional)',
                helper:
                    'When you usually play, so squads know when to invite you.',
              ),
              Row(
                children: [
                  Expanded(
                    child: _TimeTile(
                      label: 'From',
                      value: _availableFrom == null
                          ? null
                          : _formatTime(_availableFrom!),
                      onTap: () => _pickTime(from: true),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _TimeTile(
                      label: 'To',
                      value: _availableTo == null
                          ? null
                          : _formatTime(_availableTo!),
                      onTap: () => _pickTime(from: false),
                    ),
                  ),
                ],
              ),
              if (_availableFrom != null || _availableTo != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() {
                      _availableFrom = null;
                      _availableTo = null;
                    }),
                    child: const Text('Clear time'),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _lookingForController,
                maxLength: 100,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Looking for (optional)',
                  prefixIcon: Icon(Icons.groups_outlined),
                  helperText: 'e.g. Esports squad',
                  counterText: '',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _achievementsController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Achievements (optional)',
                  prefixIcon: Icon(Icons.emoji_events_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_error != null) ...[
                MessageBanner(message: _error!),
                const SizedBox(height: AppSpacing.md),
              ],
              PrimaryButton(
                label: 'Save BGMI profile',
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
                    'Remove BGMI profile',
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

class _FieldLabel extends StatelessWidget {
  final String title;
  final String helper;

  const _FieldLabel({required this.title, required this.helper});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            helper,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Years of experience with -/+ buttons; going below "Under 1 year" clears it.
class _ExperienceStepper extends StatelessWidget {
  final int? years;
  final int maxYears;
  final String label;
  final ValueChanged<int?> onChanged;

  const _ExperienceStepper({
    required this.years,
    required this.maxYears,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final current = years;
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Fewer years',
            icon: const Icon(Icons.remove),
            onPressed: current == null
                ? null
                : () => onChanged(current == 0 ? null : current - 1),
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: current == null
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            tooltip: 'More years',
            icon: const Icon(Icons.add),
            onPressed: current != null && current >= maxYears
                ? null
                : () => onChanged(current == null ? 0 : current + 1),
          ),
        ],
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _TimeTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label ${value ?? 'not set'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.input),
            border: Border.all(
              color: value == null ? AppColors.border : AppColors.primary,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.schedule_outlined,
                size: 20,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      value ?? 'Select',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: value == null
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
