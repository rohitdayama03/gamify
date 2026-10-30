import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/connection_model.dart';
import '../../widgets/player_avatar.dart';

/// Checklist of friends with a username filter, for choosing who to invite to a squad.
/// Players in [unavailable] (already in the squad or invited) are listed but can't be picked.
class FriendPicker extends StatefulWidget {
  final List<PlayerSummary> friends;
  final Set<int> selected;
  final Map<int, String> unavailable;
  final ValueChanged<Set<int>> onChanged;

  const FriendPicker({
    super.key,
    required this.friends,
    required this.selected,
    required this.onChanged,
    this.unavailable = const {},
  });

  @override
  State<FriendPicker> createState() => _FriendPickerState();
}

class _FriendPickerState extends State<FriendPicker> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggle(int playerId) {
    final next = {...widget.selected};
    if (!next.remove(playerId)) next.add(playerId);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.friends.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Add friends from Discover first. Only friends can be invited to a squad.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final query = _searchController.text.trim().toLowerCase();
    final friends = [...widget.friends]..sort((a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()));
    final shown = query.isEmpty ? friends : friends.where((f) => f.username.toLowerCase().startsWith(query)).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SizedBox(
            height: 44,
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search friends',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                prefixIcon: Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? Center(child: Text('No friends match "$query"', style: const TextStyle(color: AppColors.textSecondary)))
              : ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (_, index) {
                    final friend = shown[index];
                    final reason = widget.unavailable[friend.playerId];
                    return CheckboxListTile(
                      value: reason != null || widget.selected.contains(friend.playerId),
                      onChanged: reason != null ? null : (_) => _toggle(friend.playerId),
                      activeColor: AppColors.primary,
                      checkColor: AppColors.onPrimary,
                      secondary: PlayerAvatar(name: friend.username, url: friend.avatarUrl),
                      title: Text(friend.username, overflow: TextOverflow.ellipsis),
                      subtitle: reason == null ? null : Text(reason, style: const TextStyle(color: AppColors.textSecondary)),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
