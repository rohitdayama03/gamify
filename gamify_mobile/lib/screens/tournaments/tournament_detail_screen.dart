import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time_format.dart';
import '../../models/tournament_format_model.dart';
import '../../models/tournament_model.dart';
import '../../providers/tournament_provider.dart';
import '../../widgets/game_logo.dart';
import '../../widgets/primary_button.dart';
import '../messages/chat_screen.dart';
import '../player/player_profile_screen.dart';
import 'finish_stage_screen.dart';
import 'fixtures_view.dart';
import 'format_builder_screen.dart';
import 'match_result_sheet.dart';
import 'record_result_screen.dart';
import 'standings_view.dart';
import 'start_tournament_sheet.dart';
import 'tournament_card.dart';
import '../../widgets/player_avatar.dart';

/// A tournament's page. Players request to join or withdraw; the organizer answers requests and can cancel it.
/// The organizer and accepted players can open the announcements.
///
/// A simple tournament is settled by recording placements. A tournament with a format gets tabs for its
/// fixtures, group tables and leaderboard: the organizer starts it once full, enters each match result from
/// Fixtures and finishes it stage by stage.
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

class _TournamentDetailScreenState extends State<TournamentDetailScreen> with SingleTickerProviderStateMixin {
  TournamentDetail? _detail;
  // Tournaments with a format only
  TournamentFixtures? _fixtures;
  TournamentLeaderboard? _leaderboard;
  TabController? _tabs;
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

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final detail = await _provider.fetchTournament(widget.tournamentId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (detail != null) _detail = detail;
      _loadError = detail == null ? _provider.errorMessage : null;
      if (detail?.format != null) _tabs ??= TabController(length: 4, vsync: this);
    });
    if (detail?.format != null) await _loadFormatData();
  }

  Future<void> _loadFormatData() async {
    final results = await Future.wait([
      _provider.fetchFixtures(widget.tournamentId),
      _provider.fetchLeaderboard(widget.tournamentId),
    ]);
    if (!mounted) return;
    setState(() {
      _fixtures = results[0] as TournamentFixtures? ?? _fixtures;
      _leaderboard = results[1] as TournamentLeaderboard? ?? _leaderboard;
    });
  }

  // After an action that answered with the tournament: show it, then refresh the fixtures and tables
  void _applyUpdate(TournamentDetail updated) {
    setState(() => _detail = updated);
    if (updated.format != null) _loadFormatData();
  }

  Future<void> _start(TournamentDetail detail) async {
    final choice = await StartTournamentSheet.show(context, detail.accepted);
    if (choice == null || !mounted) return;
    await _run(() => _provider.startTournament(detail.tournament.id, order: choice.order), 'The draw is done. Fixtures are locked.');
    if (mounted && _detail?.tournament.inProgress == true) _tabs?.animateTo(1);
  }

  Future<void> _editFormat(TournamentDetail detail) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FormatBuilderScreen(
          initial: FormatDraft.fromFormat(detail.format!),
          saveLabel: 'Save format',
          onSave: (draft) async {
            final updated = await _provider.updateFormat(detail.tournament.id, draft);
            if (updated == null) return _provider.errorMessage ?? 'Could not save the format';
            if (mounted) _applyUpdate(updated);
            return null;
          },
        ),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Format saved. The fixtures have been redrawn.')));
    }
  }

  Future<void> _enterResult(TournamentMatch match) async {
    final detail = _detail;
    final fixtures = _fixtures;
    if (detail?.format == null || fixtures == null) return;
    final knockout = fixtures.stages.any((s) => s.type == StageType.knockout && s.matches.any((m) => m.id == match.id));
    final updated = await MatchResultSheet.show(
      context,
      tournamentId: detail!.tournament.id,
      match: match,
      knockout: knockout,
      stats: detail.format!.stats,
    );
    if (updated == null || !mounted) return;
    setState(() => _fixtures = updated);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Result saved. Both players have been notified.')));
    // Progress counts and tables changed too
    final fresh = await _provider.fetchTournament(widget.tournamentId);
    if (fresh != null && mounted) setState(() => _detail = fresh);
    final leaderboard = await _provider.fetchLeaderboard(widget.tournamentId);
    if (leaderboard != null && mounted) setState(() => _leaderboard = leaderboard);
  }

  Future<void> _finishStage(TournamentDetail detail, FormatStage stage, bool isLast) async {
    if (stage.type == StageType.knockout) {
      final confirmed = await _confirm(
        title: 'Finish the tournament?',
        message: 'Placements are set from the knockout results and every player is notified. Results are locked after this.',
        action: 'Finish',
        destructive: false,
      );
      if (!confirmed || !mounted) return;
      await _run(() => _provider.finishStage(detail.tournament.id, stage.id), 'Tournament finished. Congratulations to the champion!');
      return;
    }
    // Use the latest tables so the order shown is the order saved
    final leaderboard = await _provider.fetchLeaderboard(detail.tournament.id);
    if (!mounted) return;
    StageTable? table;
    for (final t in leaderboard?.stages ?? const <StageTable>[]) {
      if (t.stageId == stage.id) table = t;
    }
    if (table == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_provider.errorMessage ?? 'Could not load the tables')));
      return;
    }
    final updated = await Navigator.push<TournamentDetail>(
      context,
      MaterialPageRoute(
        builder: (_) => FinishStageScreen(tournamentId: detail.tournament.id, stage: stage, table: table!, isLast: isLast),
      ),
    );
    if (updated == null || !mounted) return;
    _applyUpdate(updated);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(isLast ? 'Tournament finished. Congratulations to the champion!' : 'Stage ${stage.seq} finished. Stage ${stage.seq + 1} is ready.'),
    ));
  }

  // Runs an action that answers with the updated tournament, showing [success] or the error
  Future<void> _run(Future<TournamentDetail?> Function() action, String success, {bool setsActing = true}) async {
    final messenger = ScaffoldMessenger.of(context);
    if (setsActing) setState(() => _acting = true);
    final updated = await action();
    if (!mounted) return;
    setState(() {
      if (setsActing) _acting = false;
    });
    if (updated != null) _applyUpdate(updated);
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

  Future<bool> _confirm({required String title, required String message, required String action, bool destructive = true}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action, style: TextStyle(color: destructive ? AppColors.error : AppColors.primary)),
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
    final tabs = detail?.format != null ? _tabs : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(t?.name ?? widget.name ?? 'Tournament'),
        bottom: tabs == null
            ? null
            : TabBar(
                controller: tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: const [Tab(text: 'Overview'), Tab(text: 'Fixtures'), Tab(text: 'Standings'), Tab(text: 'Leaderboard')],
              ),
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
              : tabs == null
                  ? RefreshIndicator(onRefresh: _load, child: _buildBody(detail))
                  : TabBarView(
                      controller: tabs,
                      children: [
                        RefreshIndicator(onRefresh: _load, child: _buildBody(detail)),
                        _tabContent(
                          _fixtures,
                          (f) => FixturesView(
                            fixtures: f,
                            onRefresh: _loadFormatData,
                            onEditMatch: t!.myRole == TournamentRole.organizer ? _enterResult : null,
                          ),
                        ),
                        _tabContent(_leaderboard, (l) => StandingsView(leaderboard: l, onRefresh: _loadFormatData)),
                        _tabContent(
                          _leaderboard,
                          (l) => LeaderboardView(leaderboard: l, completed: t!.completed, onRefresh: _loadFormatData),
                        ),
                      ],
                    ),
    );
  }

  Widget _tabContent<T>(T? data, Widget Function(T data) builder) {
    if (data != null) return builder(data);
    return RefreshIndicator(
      onRefresh: _loadFormatData,
      child: ListView(children: const [SizedBox(height: 120), Center(child: CircularProgressIndicator())]),
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
        if (detail.format != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text('FORMAT', style: AppFonts.label()),
          const SizedBox(height: AppSpacing.xs),
          _FormatOverview(format: detail.format!, started: !t.isOpen),
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
        if (isOrganizer && detail.pending.isNotEmpty && t.isOpen) ...[
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
      case TournamentRole.organizer when detail.format != null:
        final actions = _formatActions(detail);
        return [
          ...actions,
          if (actions.isNotEmpty) const SizedBox(height: AppSpacing.xs),
          chatButton,
        ];
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
          MessageBanner(
            message: t.hasFormat && !t.isOpen
                ? "You're in! Your matches and results are in Fixtures."
                : t.hasFormat
                    ? "You're in! The fixtures appear once the organizer starts the tournament."
                    : "You're in! Watch the announcements for match details.",
            isError: false,
          ),
          const SizedBox(height: AppSpacing.xs),
          chatButton,
          if (t.isOpen)
            TextButton(onPressed: _acting ? null : () => _withdraw(t), child: const Text('Leave tournament')),
        ];
      case TournamentRole.pending:
        return [
          const MessageBanner(message: 'Request sent. The organizer will accept or decline it.', isError: false),
          if (t.isOpen)
            TextButton(onPressed: _acting ? null : () => _withdraw(t), child: const Text('Withdraw request')),
        ];
      case TournamentRole.rejected:
        return [const MessageBanner(message: "The organizer didn't accept your request.")];
      case TournamentRole.none:
        final String? closedReason = t.completed
            ? 'This tournament is over'
            : t.inProgress
                ? 'This tournament is under way'
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

/// Organizer buttons for a tournament with a format: start it once full (or edit the format before anyone is
/// accepted), then finish each stage once all its results are in.
extension on _TournamentDetailScreenState {
  List<Widget> _formatActions(TournamentDetail detail) {
    final format = detail.format!;
    final t = detail.tournament;
    if (t.isOpen) {
      final missing = format.slots - detail.accepted.length;
      return [
        PrimaryButton(
          label: missing > 0 ? 'Waiting for $missing more player${missing == 1 ? '' : 's'}' : 'Start tournament',
          icon: Icons.play_arrow,
          loading: _acting,
          onPressed: missing > 0 ? null : () => _start(detail),
        ),
        if (format.editable) ...[
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            onPressed: () => _editFormat(detail),
            icon: const Icon(Icons.tune),
            label: const Text('Edit format'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        ],
      ];
    }
    final stage = format.currentStage;
    if (!t.inProgress || stage == null) return [];
    final isLast = stage.seq == format.stages.length;
    final remaining = stage.matchCount - stage.completedCount;
    if (remaining > 0) {
      return [
        MessageBanner(
          message: 'Stage ${stage.seq}: ${stage.completedCount} of ${stage.matchCount} results in. '
              'Tap a match in Fixtures to enter its result.',
          isError: false,
        ),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton.icon(
          onPressed: () => _tabs?.animateTo(1),
          icon: const Icon(Icons.sports_soccer),
          label: const Text('Go to fixtures'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
      ];
    }
    return [
      PrimaryButton(
        label: isLast ? 'Finish tournament' : 'Finish stage ${stage.seq}',
        icon: Icons.flag,
        loading: _acting,
        onPressed: () => _finishStage(detail, stage, isLast),
      ),
    ];
  }
}

/// The stages in order with their progress: done, under way (results in so far) or still to come.
class _FormatOverview extends StatelessWidget {
  final TournamentFormat format;
  final bool started;

  const _FormatOverview({required this.format, required this.started});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final stage in format.stages)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  stage.finished
                      ? Icons.check_circle
                      : stage.id == format.currentStageId
                          ? Icons.play_circle_outline
                          : Icons.radio_button_unchecked,
                  size: 18,
                  color: stage.finished || stage.id == format.currentStageId ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: Text('Stage ${stage.seq} · ${stage.entrants} players · ${stage.summary}')),
                if (started)
                  Text('${stage.completedCount}/${stage.matchCount}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        if (format.stats.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Stats: ${format.stats.map((s) => s.label).join(', ')}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
      ],
    );
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
