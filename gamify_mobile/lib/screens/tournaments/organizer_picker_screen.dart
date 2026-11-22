import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/connection_model.dart';
import '../../providers/tournament_provider.dart';
import '../../widgets/player_avatar.dart';

/// Search any player by username and pick one to help organize a tournament. Pops with the chosen
/// [PlayerSummary]. Players in [unavailable] (already organizing) are listed but can't be picked.
class OrganizerPickerScreen extends StatefulWidget {
  final Set<int> unavailable;

  const OrganizerPickerScreen({super.key, required this.unavailable});

  @override
  State<OrganizerPickerScreen> createState() => _OrganizerPickerScreenState();
}

class _OrganizerPickerScreenState extends State<OrganizerPickerScreen> {
  static const _debounce = Duration(milliseconds: 300);

  final _controller = TextEditingController();
  Timer? _timer;
  // Ignores answers to searches the player has typed past
  int _searchId = 0;
  bool _searching = false;
  String? _error;
  List<PlayerSummary> _results = [];

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _timer?.cancel();
    final query = text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchId++;
        _results = [];
        _searching = false;
        _error = null;
      });
      return;
    }
    _timer = Timer(_debounce, () => _search(query));
  }

  Future<void> _search(String query) async {
    final id = ++_searchId;
    setState(() => _searching = true);
    final provider = Provider.of<TournamentProvider>(context, listen: false);
    final found = await provider.findPlayers(query);
    if (!mounted || id != _searchId) return;
    setState(() {
      _searching = false;
      _results = found ?? [];
      _error = found == null ? provider.errorMessage : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();
    return Scaffold(
      appBar: AppBar(title: const Text('Add organizer')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search by username',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : null,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Organizers can accept players, start the tournament, enter results and post announcements. '
              'Only you can cancel it or change who organizes.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildResults(query)),
        ],
      ),
    );
  }

  Widget _buildResults(String query) {
    if (_error != null) return _message(_error!);
    if (query.isEmpty) return _message('Type a username to find a player');
    if (_results.isEmpty) return _searching ? const SizedBox.shrink() : _message('No players match "$query"');
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (_, index) {
        final player = _results[index];
        final taken = widget.unavailable.contains(player.playerId);
        return ListTile(
          enabled: !taken,
          leading: PlayerAvatar(name: player.username, url: player.avatarUrl),
          title: Text(player.username, overflow: TextOverflow.ellipsis),
          subtitle: taken ? const Text('Already an organizer', style: TextStyle(color: AppColors.textSecondary)) : null,
          trailing: taken ? null : const Icon(Icons.person_add_alt, color: AppColors.primary),
          onTap: taken ? null : () => Navigator.pop(context, player),
        );
      },
    );
  }

  Widget _message(String text) => Padding(
        padding: const EdgeInsets.all(32),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
      );
}
