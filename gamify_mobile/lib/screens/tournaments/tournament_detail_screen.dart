import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time_format.dart';
import '../../models/tournament_model.dart';
import '../../providers/tournament_provider.dart';
import '../../widgets/game_logo.dart';
import '../../widgets/primary_button.dart';
import '../messages/chat_screen.dart';
import '../player/player_profile_screen.dart';
import 'record_result_screen.dart';
import 'tournament_card.dart';
import '../../widgets/player_avatar.dart';

/// A tournament's page. Players request to join or withdraw; the organizer answers requests,
/// records the result and can cancel it. The organizer and accepted players can open the announcements.
class TournamentDetailScreen extends StatefulWidget {
  final int tournamentId;
  // Shown in the app bar while the tournament loads
  final String? name;

  const TournamentDetailScreen({super.key, required this.tournamentId, this.name});

  static Future<void> open(BuildContext context, int tournamentId, {String? name}) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TournamentDetailScreen(tournamentId: tournamentId, name: name)),
      );

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen> {
  TournamentDetail? _detail;
  bool _loading = true;
  String? _loadError;
  // The join / withdraw button's request is in flight
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  TournamentProvider get _provider => Provider.of<TournamentProvider>(context, listen: false);

  Future<void> _load() async {
    final detail = await _provider.fetchTournament(widget.tournamentId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (detail != null) _detail = detail;
      _loadError = detail == null ? _provider.errorMessage : null;
    });
  }

  // Runs an action that answers with the updated tournament, showing [success] or the error
  Future<void> _run(Future<TournamentDetail?> Function() action, String success, {bool setsActing = true}) async {
    final messenger = ScaffoldMessenger.of(context);
    if (setsActing) setState(() => _acting = true);
    final updated = await action();
    if (!mounted) return;
    setState(() {
      if (setsActing) _acting = false;
      if (updated != null) _detail = updated;
    });
    messenger.showSnackBar(SnackBar(content: Text(updated != null ? success : _provider.errorMessage ?? 'Something went wrong')));
    // A failure usually means our copy was stale (e.g. the tournament filled up); show the current state
    if (updated == null) _load();
  }

  Future<void> _withdraw(TournamentSummary t) async {
    final leaving = t.myRole == TournamentRole.accepted;
    final confirmed = await _confirm(
      title: leaving ? 'Leave ${t.name}?' : 'Withdraw request?',
      message: leaving
          ? "You'll lose your spot and stop getting announcements. You can ask to join again while it's open."
          : 'The organizer will no longer see your request.',
      action: leaving ? 'Leave' : 'Withdraw',
    );
    if (!confirmed || !mounted) return;
    await _run(() => _provider.withdraw(t.id), leaving ? 'You left ${t.name}' : 'Request withdrawn');
  }

  Future<void> _cancelTournament(TournamentSummary t) async {
    final confirmed = await _confirm(
      title: 'Cancel ${t.name}?',
      message: 'The tournament, its requests and announcements will be deleted. Accepted players are notified.',
      action: 'Cancel tournament',
    );
    if (!confirmed || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ok = await _provider.deleteTournament(t.id);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(ok ? '${t.name} cancelled' : _provider.errorMessage ?? 'Something went wrong')));
    if (ok) navigator.pop();
  }

  Future<void> _recordResult(TournamentDetail detail) async {
    final updated = await Navigator.push<TournamentDetail>(
      context,
      MaterialPageRoute(builder: (_) => RecordResultScreen(detail: detail)),
    );
    if (updated != null && mounted) setState(() => _detail = updated);
  }

  void _openChat(TournamentSummary t) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen.tournament(
          tournamentId: t.id,
          tournamentName: t.name,
          isOrganizer: t.myRole == TournamentRole.organizer,
        ),
      ),
    );
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
    final detail = _detail;
    final t = detail?.tournament;
    return Scaffold(
      appBar: AppBar(
        title: Text(t?.name ?? widget.name ?? 'Tournament'),
        actions: [
          if (t != null && t.myRole == TournamentRole.organizer)
            PopupMenuButton<String>(
              onSelected: (_) => _cancelTournament(t),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'cancel', child: Text('Cancel tournament', style: TextStyle(color: AppColors.error))),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : detail == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      _loadError ?? 'This tournament no longer exists',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              : RefreshIndicator(onRefresh: _load, child: _buildBody(detail)),
    );
  }

  Widget _buildBody(TournamentDetail detail) {
    final t = detail.tournament;
    final isOrganizer = t.myRole == TournamentRole.organizer;
    final game = t.game;
    final placed = detail.accepted.where((p) => p.placement != null).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.md, AppSpacing.gutter, AppSpacing.lg),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (game != null) GameLogo(game: game, width: 72, height: 52),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.name, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(game?.label ?? '', style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
            TournamentStatusChip(tournament: t),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _InfoRow(icon: Icons.event_outlined, text: formatDateTime(t.startsAt)),
        _InfoRow(icon: Icons.groups_outlined, text: t.slotsLabel),
        OpenProfileOnTap(
          playerId: t.organizer.playerId,
          username: t.organizer.username,
          child: _InfoRow(icon: Icons.person_outline, text: 'Organized by ${t.organizer.username}'),
        ),
        if (t.description != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(t.description!, style: const TextStyle(height: 1.4)),
        ],
        const SizedBox(height: AppSpacing.md),
        ..._buildActions(detail),
        if (t.completed) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('RESULT', style: AppFonts.label()),
          const SizedBox(height: AppSpacing.xs),
          if (placed.isEmpty)
            const Text('No placements recorded.', style: TextStyle(color: AppColors.textSecondary))
          else
            for (final p in placed) _ParticipantTile(participant: p, highlight: p.placement == 1),
          if (detail.resultNotes != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(detail.resultNotes!, style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
          ],
        ],
        if (isOrganizer && detail.pending.isNotEmpty && !t.completed) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('REQUESTS  [${detail.pending.length}]', style: AppFonts.label()),
          const SizedBox(height: AppSpacing.xs),
          for (final p in detail.pending) _RequestTile(request: p, onAnswered: (updated) => setState(() => _detail = updated)),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text('PARTICIPANTS  [${detail.accepted.length}]', style: AppFonts.label()),
        const SizedBox(height: AppSpacing.xs),
        if (detail.accepted.isEmpty)
          Text(
            isOrganizer ? 'Accept requests to fill your tournament.' : 'No one has been accepted yet.',
            style: const TextStyle(color: AppColors.textSecondary),
          )
        else
          for (final p in detail.accepted) _ParticipantTile(participant: p, highlight: false),
      ],
    );
  }

  List<Widget> _buildActions(TournamentDetail detail) {
    final t = detail.tournament;
    final chatButton = OutlinedButton.icon(
      onPressed: () => _openChat(t),
      icon: const Icon(Icons.campaign_outlined),
      label: Text(t.myRole == TournamentRole.organizer ? 'Post announcements' : 'Announcements'),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    );

    switch (t.myRole) {
      case TournamentRole.organizer:
        return [
          if (detail.accepted.isNotEmpty) ...[
            PrimaryButton(
              label: t.completed ? 'Edit result' : 'Record result',
              icon: Icons.emoji_events,
              onPressed: () => _recordResult(detail),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          chatButton,
        ];
      case TournamentRole.accepted:
        return [
          const MessageBanner(message: "You're in! Watch the announcements for match details.", isError: false),
          const SizedBox(height: AppSpacing.xs),
          chatButton,
          if (!t.completed)
            TextButton(onPressed: _acting ? null : () => _withdraw(t), child: const Text('Leave tournament')),
        ];
      case TournamentRole.pending:
        return [
          const MessageBanner(message: 'Request sent. The organizer will accept or decline it.', isError: false),
          if (!t.completed)
            TextButton(onPressed: _acting ? null : () => _withdraw(t), child: const Text('Withdraw request')),
        ];
      case TournamentRole.rejected:
        return [const MessageBanner(message: "The organizer didn't accept your request.")];
      case TournamentRole.none:
        final String? closedReason = t.completed
            ? 'This tournament is over'
            : t.hasStarted
                ? 'Requests closed when it started'
                : t.isFull
                    ? 'This tournament is full'
                    : null;
        if (closedReason != null) return [MessageBanner(message: closedReason, isError: false)];
        return [
          PrimaryButton(
            label: 'Request to join',
            icon: Icons.how_to_reg,
            loading: _acting,
            onPressed: () => _run(() => _provider.requestToJoin(t.id), 'Request sent to ${t.organizer.username}'),
          ),
        ];
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.secondary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  final TournamentParticipant participant;
  final bool highlight;

  const _ParticipantTile({required this.participant, required this.highlight});

  @override
  Widget build(BuildContext context) {
    final player = participant.player;
    final placement = participant.placement;
    return OpenProfileOnTap(
      playerId: player.playerId,
      username: player.username,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        // The winner gets a trophy instead of their picture
        leading: highlight
            ? const CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Icon(Icons.emoji_events, color: AppColors.onPrimary),
              )
            : PlayerAvatar(name: player.username, url: player.avatarUrl),
        title: Text(player.username, overflow: TextOverflow.ellipsis),
        trailing: placement == null
            ? null
            : Text(
                ordinal(placement),
                style: TextStyle(color: highlight ? AppColors.primary : AppColors.textSecondary, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}

/// A pending join request with Accept / Decline, for the organizer.
class _RequestTile extends StatelessWidget {
  final TournamentParticipant request;
  final ValueChanged<TournamentDetail> onAnswered;

  const _RequestTile({required this.request, required this.onAnswered});

  Future<void> _answer(BuildContext context, bool accept) async {
    final provider = Provider.of<TournamentProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final name = request.player.username;
    final updated = accept ? await provider.acceptRequest(request.id) : await provider.rejectRequest(request.id);
    if (updated != null) onAnswered(updated);
    messenger.showSnackBar(SnackBar(
      content: Text(updated == null
          ? provider.errorMessage ?? 'Something went wrong'
          : accept
              ? '$name is in'
              : 'Declined $name'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final busy = Provider.of<TournamentProvider>(context).isBusy(request.id);
    final player = request.player;
    return OpenProfileOnTap(
      playerId: player.playerId,
      username: player.username,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            PlayerAvatar(name: player.username, url: player.avatarUrl),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(player.username, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(timeAgo(request.requestedAt), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Decline ${player.username}',
              onPressed: busy ? null : () => _answer(context, false),
              icon: const Icon(Icons.close, color: AppColors.textSecondary),
            ),
            IconButton.filled(
              tooltip: 'Accept ${player.username}',
              onPressed: busy ? null : () => _answer(context, true),
              style: IconButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.onPrimary),
              icon: busy
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary))
                  : const Icon(Icons.check),
            ),
          ],
        ),
      ),
    );
  }
}
