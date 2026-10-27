import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/game.dart';
import '../../providers/player_provider.dart';
import 'edit_gta_profile_screen.dart';

class EditGameProfilesScreen extends StatefulWidget {
  final int initialTab;
  const EditGameProfilesScreen({super.key, this.initialTab = 0});

  /// Opens the profile editor for [game]; GTA Online has its own screen, BGMI and eFootball share this one
  static Future<void> open(BuildContext context, Game game) {
    final screen = switch (game) {
      Game.gta => const EditGtaProfileScreen(),
      Game.bgmi => const EditGameProfilesScreen(initialTab: 0),
      Game.efootball => const EditGameProfilesScreen(initialTab: 1),
    };
    return Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  State<EditGameProfilesScreen> createState() => _EditGameProfilesScreenState();
}

class _EditGameProfilesScreenState extends State<EditGameProfilesScreen> {
  final _bgmiId = TextEditingController();
  final _role = TextEditingController();
  final _exp = TextEditingController();
  final _time = TextEditingController();
  final _achievements = TextEditingController();
  final _lookingFor = TextEditingController();

  final _efootballId = TextEditingController();
  final _highTier = TextEditingController();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = Provider.of<PlayerProvider>(context, listen: false).currentPlayer;
    if (p?.bgmiProfile != null) {
      _bgmiId.text = p!.bgmiProfile!.bgmiId;
      _role.text = p.bgmiProfile!.currentRole ?? '';
      _exp.text = p.bgmiProfile!.experience ?? '';
      _time.text = p.bgmiProfile!.availableTime ?? '';
      _achievements.text = p.bgmiProfile!.achievements ?? '';
      _lookingFor.text = p.bgmiProfile!.lookingFor ?? '';
    }
    if (p?.efootballProfile != null) {
      _efootballId.text = p!.efootballProfile!.efootballId;
      _highTier.text = p.efootballProfile!.highTier ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in [_bgmiId, _role, _exp, _time, _achievements, _lookingFor, _efootballId, _highTier]) {
      c.dispose();
    }
    super.dispose();
  }

  // Runs a save/delete call, then closes the screen on success or shows the error
  Future<void> _run(Future<bool> Function(PlayerProvider) action) async {
    final provider = Provider.of<PlayerProvider>(context, listen: false);
    setState(() => _saving = true);
    final ok = await action(provider);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.errorMessage ?? 'Something went wrong')));
    }
  }

  void _saveBgmi() {
    if (_bgmiId.text.trim().isEmpty) {
      _showRequired('BGMI In-Game ID');
      return;
    }
    _run((p) => p.updateBgmiProfile({
          'bgmiId': _bgmiId.text.trim(),
          'currentRole': _role.text.trim(),
          'experience': _exp.text.trim(),
          'availableTime': _time.text.trim(),
          'achievements': _achievements.text.trim(),
          'lookingFor': _lookingFor.text.trim(),
        }));
  }

  void _saveEfootball() {
    if (_efootballId.text.trim().isEmpty) {
      _showRequired('E-Football ID');
      return;
    }
    _run((p) => p.updateEfootballProfile({
          'efootballId': _efootballId.text.trim(),
          'highTier': _highTier.text.trim(),
        }));
  }

  void _showRequired(String field) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$field is required')));
  }

  Future<void> _confirmRemove(String game, Future<bool> Function(PlayerProvider) delete) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove $game profile?'),
        content: Text('Your $game details will be deleted from your profile.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) _run(delete);
  }

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerProvider>(context).currentPlayer;

    return DefaultTabController(
      initialIndex: widget.initialTab,
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Game Profiles'),
          bottom: const TabBar(tabs: [Tab(text: 'BGMI'), Tab(text: 'E-Football')]),
        ),
        body: TabBarView(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(controller: _bgmiId, decoration: const InputDecoration(labelText: 'BGMI In-Game ID *')),
                  const SizedBox(height: 12),
                  TextField(controller: _role, decoration: const InputDecoration(labelText: 'Current Role (e.g. IGL, Assaulter)')),
                  const SizedBox(height: 12),
                  TextField(controller: _exp, decoration: const InputDecoration(labelText: 'Experience (e.g. 2 Years)')),
                  const SizedBox(height: 12),
                  TextField(controller: _time, decoration: const InputDecoration(labelText: 'Available Time (e.g. 8 PM - 11 PM)')),
                  const SizedBox(height: 12),
                  TextField(controller: _achievements, maxLines: 3, decoration: const InputDecoration(labelText: 'Achievements', alignLabelWithHint: true)),
                  const SizedBox(height: 12),
                  TextField(controller: _lookingFor, decoration: const InputDecoration(labelText: 'Looking For (e.g. Esports Squad)')),
                  const SizedBox(height: 20),
                  _saveButton('Save BGMI Profile', _saveBgmi),
                  if (player?.bgmiProfile != null)
                    _removeButton('BGMI', (p) => p.deleteBgmiProfile()),
                ],
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(controller: _efootballId, decoration: const InputDecoration(labelText: 'E-Football ID *')),
                  const SizedBox(height: 12),
                  TextField(controller: _highTier, decoration: const InputDecoration(labelText: 'Highest Tier (e.g. Div 1)')),
                  const SizedBox(height: 20),
                  _saveButton('Save E-Football Profile', _saveEfootball),
                  if (player?.efootballProfile != null)
                    _removeButton('E-Football', (p) => p.deleteEfootballProfile()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _saveButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: AppColors.primary),
      onPressed: _saving ? null : onPressed,
      child: _saving
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary))
          : Text(label, style: const TextStyle(color: AppColors.onPrimary)),
    );
  }

  Widget _removeButton(String game, Future<bool> Function(PlayerProvider) delete) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextButton.icon(
        icon: const Icon(Icons.delete_outline, color: AppColors.error),
        label: Text('Remove $game Profile', style: const TextStyle(color: AppColors.error)),
        onPressed: _saving ? null : () => _confirmRemove(game, delete),
      ),
    );
  }
}
