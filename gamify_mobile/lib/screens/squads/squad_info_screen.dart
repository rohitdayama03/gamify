import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/time_format.dart';
import '../../models/squad_model.dart';
import '../../providers/player_provider.dart';
import '../../providers/connection_provider.dart';
import '../../providers/squad_provider.dart';
import '../../widgets/primary_button.dart';
import '../player/player_profile_screen.dart';
import 'friend_picker.dart';
import '../../widgets/player_avatar.dart';

/// Members and pending invites of a squad. Any member can invite friends and leave;
/// the owner can also remove members and withdraw invites. Pops with true after leaving.
class SquadInfoScreen extends StatefulWidget {
  final int squadId;
  final String squadName;

  const SquadInfoScreen({super.key, required this.squadId, required this.squadName});

  @override
  State<SquadInfoScreen> createState() => _SquadInfoScreenState();
}

class _SquadInfoScreenState extends State<SquadInfoScreen> {
  SquadDetail? _squad;
  bool _loading = true;
  String? _loadError;
  // Player ids with a remove request in flight
  final Set<int> _removing = {};
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final provider = Provider.of<SquadProvider>(context, listen: false);
    final squad = await provider.fetchSquad(widget.squadId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (squad != null) _squad = squad;
      _loadError = squad == null ? provider.errorMessage : null;
    });
  }

  Future<void> _addMembers() async {
    final squad = _squad;
    if (squad == null) return;
    final updated = await Navigator.push<SquadDetail>(
      context,
      MaterialPageRoute(builder: (_) => _AddMembersScreen(squad: squad)),
    );
    if (updated != null && mounted) setState(() => _squad = updated);
  }

  Future<void> _remove(SquadMember member) async {
    final name = member.player.username;
    final confirmed = await _confirm(
      title: member.joined ? 'Remove $name?' : 'Cancel invite?',
      message: member.joined
          ? '$name will leave ${_squad!.name}. You can invite them again later.'
          : "$name won't be able to join with this invite.",
      action: member.joined ? 'Remove' : 'Cancel invite',
    );
    if (!confirmed || !mounted) return;
    final provider = Provider.of<SquadProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _removing.add(member.player.playerId));
    final updated = await provider.removeMember(widget.squadId, member.player.playerId);
    if (!mounted) return;
    setState(() {
      _removing.remove(member.player.playerId);
      if (updated != null) _squad = updated;
    });
    if (updated == null) messenger.showSnackBar(SnackBar(content: Text(provider.errorMessage ?? 'Something went wrong')));
  }

  Future<void> _leave() async {
    final squad = _squad!;
    final othersJoined = squad.joined.length - 1;
    final confirmed = await _confirm(
      title: 'Leave ${squad.name}?',
      message: othersJoined == 0
          ? "You're the last member, so the squad and its messages will be deleted."
          : squad.isOwner
              ? 'Ownership passes to the member who joined after you.'
              : "You'll stop getting its messages. A member can invite you back.",
      action: 'Leave',
    );
    if (!confirmed || !mounted) return;
    final provider = Provider.of<SquadProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _leaving = true);
    final ok = await provider.leaveSquad(widget.squadId);
    if (!mounted) return;
    setState(() => _leaving = false);
    if (ok) {
      messenger.showSnackBar(SnackBar(content: Text('You left ${squad.name}')));
      Navigator.pop(context, true);
    } else {
      messenger.showSnackBar(SnackBar(content: Text(provider.errorMessage ?? 'Could not leave the squad')));
    }
  }

  Future<bool> _confirm({required String title, required String message, required String action}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action, style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final squad = _squad;
    return Scaffold(
      appBar: AppBar(title: Text(squad?.name ?? widget.squadName)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : squad == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(_loadError ?? 'Squad not found', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                  ),
                )
              : RefreshIndicator(onRefresh: _load, child: _buildDetail(squad)),
    );
  }

  Widget _buildDetail(SquadDetail squad) {
    final myId = Provider.of<PlayerProvider>(context).currentPlayer?.playerId;
    final joined = squad.joined;
    final invited = squad.invited;

    return ListView(
      children: [
        const SizedBox(height: 24),
        const Center(
          child: CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.primary,
            child: Icon(Icons.groups, size: 36, color: AppColors.onPrimary),
          ),
        ),
        const SizedBox(height: 12),
        Center(child: Text(squad.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
        const SizedBox(height: 4),
        Center(
          child: Text(
            '${joined.length} member${joined.length == 1 ? '' : 's'}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: OutlinedButton.icon(
            onPressed: _addMembers,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Invite friends'),
          ),
        ),
        _SectionLabel('MEMBERS · ${joined.length}'),
        for (final member in joined)
          _MemberTile(
            member: member,
            isMe: member.player.playerId == myId,
            isOwner: member.player.playerId == squad.ownerId,
            busy: _removing.contains(member.player.playerId),
            onRemove: squad.isOwner && member.player.playerId != myId ? () => _remove(member) : null,
          ),
        if (invited.isNotEmpty) ...[
          _SectionLabel('INVITED · ${invited.length}'),
          for (final member in invited)
            _MemberTile(
              member: member,
              isMe: false,
              isOwner: false,
              busy: _removing.contains(member.player.playerId),
              onRemove: squad.isOwner ? () => _remove(member) : null,
            ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          child: OutlinedButton.icon(
            onPressed: _leaving ? null : _leave,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              minimumSize: const Size.fromHeight(48),
            ),
            icon: _leaving
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.logout),
            label: const Text('Leave squad'),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.6),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final SquadMember member;
  final bool isMe;
  final bool isOwner;
  final bool busy;
  final VoidCallback? onRemove;

  const _MemberTile({required this.member, required this.isMe, required this.isOwner, required this.busy, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final player = member.player;
    final subtitle = member.joined
        ? (isOwner ? 'Owner' : null)
        : 'Invited ${timeAgo(member.invitedAt)}';
    final tile = ListTile(
      leading: PlayerAvatar(name: player.username, url: player.avatarUrl),
      title: Text(isMe ? '${player.username} (you)' : player.username, overflow: TextOverflow.ellipsis),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, style: TextStyle(color: isOwner ? AppColors.primary : AppColors.textSecondary)),
      trailing: onRemove == null
          ? null
          : busy
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : IconButton(
                  tooltip: member.joined ? 'Remove ${player.username}' : 'Cancel invite',
                  icon: Icon(member.joined ? Icons.person_remove_outlined : Icons.close, color: AppColors.textSecondary),
                  onPressed: onRemove,
                ),
    );
    return isMe ? tile : OpenProfileOnTap(playerId: player.playerId, username: player.username, child: tile);
  }
}

/// Pick friends who aren't in the squad yet and send them invites; pops with the updated squad.
class _AddMembersScreen extends StatefulWidget {
  final SquadDetail squad;

  const _AddMembersScreen({required this.squad});

  @override
  State<_AddMembersScreen> createState() => _AddMembersScreenState();
}

class _AddMembersScreenState extends State<_AddMembersScreen> {
  Set<int> _selected = {};
  bool _sending = false;

  Future<void> _invite() async {
    if (_selected.isEmpty || _sending) return;
    setState(() => _sending = true);
    final provider = Provider.of<SquadProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final count = _selected.length;
    final updated = await provider.inviteMembers(widget.squad.id, _selected.toList());
    if (!mounted) return;
    setState(() => _sending = false);
    if (updated == null) {
      messenger.showSnackBar(SnackBar(content: Text(provider.errorMessage ?? 'Could not send the invites')));
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text('Invited $count friend${count == 1 ? '' : 's'} to ${updated.name}')));
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    final friends = Provider.of<ConnectionProvider>(context).friends;
    final unavailable = {
      for (final m in widget.squad.members) m.player.playerId: m.joined ? 'Already in the squad' : 'Invite pending',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Invite friends')),
      body: Column(
        children: [
          Expanded(
            child: FriendPicker(
              friends: friends,
              selected: _selected,
              unavailable: unavailable,
              onChanged: (next) => setState(() => _selected = next),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: PrimaryButton(
                label: _selected.isEmpty ? 'Send invites' : 'Invite ${_selected.length}',
                icon: Icons.send,
                loading: _sending,
                onPressed: _selected.isEmpty ? null : _invite,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
