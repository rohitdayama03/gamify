import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/connection_model.dart';
import '../../models/player_model.dart';
import '../../providers/connection_provider.dart';
import '../../providers/player_provider.dart';
import '../messages/messages_screen.dart';

enum _Filter { game, bgmiRole, efootballTier, country, language }

class HomeScreen extends StatefulWidget {
  final VoidCallback onAvatarTap;

  const HomeScreen({super.key, required this.onAvatarTap});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  // Selected value per filter; a missing key means the filter is not applied
  final Map<_Filter, String> _filters = {};

  static const Map<_Filter, String> _filterLabels = {
    _Filter.game: 'Game',
    _Filter.bgmiRole: 'BGMI Role',
    _Filter.efootballTier: 'eFootball Tier',
    _Filter.country: 'Country',
    _Filter.language: 'Language',
  };

  static const Map<_Filter, List<String>> _filterOptions = {
    _Filter.game: ['BGMI', 'eFootball'],
    _Filter.bgmiRole: ['IGL', 'Assaulter', 'Fragger', 'Support', 'Sniper', 'Scout'],
    _Filter.efootballTier: ['Div 1', 'Div 2', 'Div 3', 'Div 4', 'Div 5', 'Div 6', 'Div 7', 'Div 8', 'Div 9', 'Div 10'],
    _Filter.country: ['India', 'Bangladesh', 'Nepal', 'Pakistan', 'Sri Lanka'],
    _Filter.language: ['English', 'Hindi', 'Bengali', 'Tamil', 'Telugu', 'Marathi'],
  };

  // Filters where the user may type a value not present in the preset list
  static const Set<_Filter> _customAllowed = {_Filter.bgmiRole, _Filter.efootballTier, _Filter.country, _Filter.language};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    Provider.of<PlayerProvider>(context, listen: false).searchPlayers(
      username: _searchController.text.trim(),
      bgmiRole: _filters[_Filter.bgmiRole],
      efootballTier: _filters[_Filter.efootballTier],
      country: _filters[_Filter.country],
      language: _filters[_Filter.language],
    );
  }

  void _onSearchChanged(String _) {
    setState(() {}); // refresh the clear (x) button
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _search);
  }

  void _setFilter(_Filter filter, String? value) {
    setState(() {
      if (value == null || value.isEmpty) {
        _filters.remove(filter);
      } else {
        _filters[filter] = value;
      }
    });
    // The game filter is applied locally, every other filter goes to the backend
    if (filter != _Filter.game) _search();
  }

  void _clearFilters() {
    setState(() => _filters.clear());
    _search();
  }

  List<PlayerResponse> _applyGameFilter(List<PlayerResponse> players) {
    switch (_filters[_Filter.game]) {
      case 'BGMI':
        return players.where((p) => p.bgmiProfile != null).toList();
      case 'eFootball':
        return players.where((p) => p.efootballProfile != null).toList();
      default:
        return players;
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final players = _applyGameFilter(playerProvider.searchResults);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(playerProvider.currentPlayer),
            _buildFilterChips(),
            const Divider(height: 1, color: AppColors.cardBackground),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _search(),
                child: _buildResults(playerProvider, players, playerProvider.currentPlayer?.playerId),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(PlayerResponse? me) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onAvatarTap,
            child: _Avatar(name: me?.username, radius: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                onSubmitted: (_) => _search(),
                textInputAction: TextInputAction.search,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search players',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        ),
                  filled: true,
                  fillColor: AppColors.cardBackground,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          for (final filter in _Filter.values) ...[
            _buildChip(filter),
            const SizedBox(width: 8),
          ],
          if (_filters.isNotEmpty)
            TextButton(onPressed: _clearFilters, child: const Text('Clear all')),
        ],
      ),
    );
  }

  Widget _buildChip(_Filter filter) {
    final value = _filters[filter];
    final selected = value != null;
    return ActionChip(
      onPressed: () => _openFilterSheet(filter),
      backgroundColor: selected ? AppColors.primary : Colors.transparent,
      side: BorderSide(color: selected ? AppColors.primary : AppColors.textSecondary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value ?? _filterLabels[filter]!,
            style: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 2),
          Icon(Icons.arrow_drop_down, size: 18, color: selected ? Colors.white : AppColors.textSecondary),
        ],
      ),
    );
  }

  Future<void> _openFilterSheet(_Filter filter) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _FilterSheet(
        title: _filterLabels[filter]!,
        options: _filterOptions[filter]!,
        selected: _filters[filter],
        allowCustom: _customAllowed.contains(filter),
      ),
    );
    // null means the sheet was dismissed; an empty string means "reset"
    if (result != null) _setFilter(filter, result);
  }

  Widget _buildResults(PlayerProvider provider, List<PlayerResponse> players, int? myId) {
    if (provider.isSearching && players.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (players.isEmpty) {
      // ListView so pull-to-refresh still works on an empty result
      return ListView(
        children: const [
          SizedBox(height: 120),
          Icon(Icons.person_search, size: 64, color: AppColors.textSecondary),
          SizedBox(height: 12),
          Center(child: Text('No players match your search', style: TextStyle(color: AppColors.textSecondary))),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: players.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) => _PlayerCard(player: players[index], isMe: players[index].playerId == myId),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final String title;
  final List<String> options;
  final String? selected;
  final bool allowCustom;

  const _FilterSheet({required this.title, required this.options, required this.selected, required this.allowCustom});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final TextEditingController _customController;

  @override
  void initState() {
    super.initState();
    final isCustom = widget.selected != null && !widget.options.contains(widget.selected);
    _customController = TextEditingController(text: isCustom ? widget.selected : '');
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  TextButton(onPressed: () => Navigator.pop(context, ''), child: const Text('Reset')),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final option in widget.options)
                    ListTile(
                      title: Text(option),
                      trailing: option == widget.selected ? const Icon(Icons.check, color: AppColors.primary) : null,
                      onTap: () => Navigator.pop(context, option),
                    ),
                ],
              ),
            ),
            if (widget.allowCustom)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: TextField(
                  controller: _customController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (v) => Navigator.pop(context, v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Or type a ${widget.title.toLowerCase()}',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.check),
                      onPressed: () => Navigator.pop(context, _customController.text.trim()),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final PlayerResponse player;
  final bool isMe;

  const _PlayerCard({required this.player, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final location = [player.country, player.language].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

    return Container(
      color: AppColors.cardBackground,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(name: player.username, radius: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player.username, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if (player.playerBio != null && player.playerBio!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(player.playerBio!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textPrimary)),
                ],
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(location, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (player.bgmiProfile != null)
                      _GameTag(label: 'BGMI${_suffix(player.bgmiProfile!.currentRole)}', color: AppColors.secondary),
                    if (player.efootballProfile != null)
                      _GameTag(label: 'eFootball${_suffix(player.efootballProfile!.highTier)}', color: AppColors.success),
                  ],
                ),
                if (!isMe) ...[
                  const SizedBox(height: 12),
                  _ConnectButton(player: player),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _suffix(String? value) => value == null || value.isEmpty ? '' : ' · $value';
}

class _ConnectButton extends StatelessWidget {
  final PlayerResponse player;

  const _ConnectButton({required this.player});

  Future<void> _run(BuildContext context, Future<bool> Function(ConnectionProvider) action, String successMessage) async {
    final provider = Provider.of<ConnectionProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await action(provider);
    messenger.showSnackBar(SnackBar(content: Text(ok ? successMessage : provider.errorMessage ?? 'Something went wrong')));
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ConnectionProvider>(context);
    final busy = provider.isInviting(player.playerId);

    switch (provider.statusWith(player.playerId)) {
      case RelationStatus.none:
        return _button(
          icon: Icons.person_add_alt_1,
          label: 'Connect',
          busy: busy,
          onPressed: () => _run(context, (p) => p.sendInvite(player.playerId), 'Invite sent to ${player.username}'),
        );
      case RelationStatus.inviteReceived:
        final invite = provider.pendingInviteFrom(player.playerId)!;
        return _button(
          icon: Icons.check,
          label: 'Accept invite',
          busy: provider.isBusy(invite.id),
          onPressed: () => _run(context, (p) => p.acceptInvite(invite.id), 'You and ${player.username} are now friends'),
        );
      case RelationStatus.inviteSent:
        return _button(icon: Icons.schedule, label: 'Pending');
      case RelationStatus.friends:
        return _button(
          icon: Icons.chat_bubble_outline,
          label: 'Message',
          onPressed: () => MessagesScreen.openChat(
            context,
            PlayerSummary(
              playerId: player.playerId,
              username: player.username,
              playerBio: player.playerBio,
              country: player.country,
              language: player.language,
            ),
          ),
        );
      case RelationStatus.declined:
        return _button(icon: Icons.block, label: 'Invite declined');
    }
  }

  // Without onPressed the button renders disabled, used for the read-only states
  Widget _button({required IconData icon, required String label, bool busy = false, VoidCallback? onPressed}) {
    final actionable = onPressed != null;
    return SizedBox(
      height: 34,
      child: OutlinedButton.icon(
        onPressed: busy ? null : onPressed,
        icon: busy
            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: actionable ? const BorderSide(color: AppColors.primary) : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }
}

class _GameTag extends StatelessWidget {
  final String label;
  final Color color;

  const _GameTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? name;
  final double radius;

  const _Avatar({required this.name, required this.radius});

  @override
  Widget build(BuildContext context) {
    final initial = (name == null || name!.isEmpty) ? null : name![0].toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary,
      child: initial == null
          ? Icon(Icons.person, color: Colors.white, size: radius)
          : Text(initial, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: radius * 0.8)),
    );
  }
}
