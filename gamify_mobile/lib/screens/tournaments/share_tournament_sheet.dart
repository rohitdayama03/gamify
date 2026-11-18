import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/links/tournament_links.dart';
import '../../models/tournament_model.dart';
import '../../providers/chat_provider.dart';
import '../../providers/connection_provider.dart';
import '../../widgets/primary_button.dart';
import '../squads/friend_picker.dart';

/// Share a tournament's link: send it to friends in Gamify chat, share it to WhatsApp and other apps, or
/// copy it. Whoever taps the link gets the tournament in the app, or the Play Store if they don't have it.
class ShareTournamentSheet extends StatelessWidget {
  final TournamentSummary tournament;

  const ShareTournamentSheet({super.key, required this.tournament});

  static Future<void> show(BuildContext context, TournamentSummary tournament) => showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        builder: (_) => ShareTournamentSheet(tournament: tournament),
      );

  String get _link => TournamentLinks.urlFor(tournament.id);

  /// The message that goes with the link.
  String get message {
    final game = tournament.game?.shortLabel;
    final what = game == null ? 'Tournament' : '$game tournament';
    return '${tournament.name} · $what on Gamify\n$_link';
  }

  Future<void> _sendToFriends(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final sent = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => _SendToFriendsScreen(message: message)),
    );
    if (sent == null) return;
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(sent == 1 ? 'Sent to 1 friend' : 'Sent to $sent friends')));
  }

  Future<void> _shareElsewhere(BuildContext context) async {
    final navigator = Navigator.of(context);
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
      text: message,
      subject: tournament.name,
      // iPad needs to know where the share popover points
      sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ));
    navigator.pop();
  }

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await Clipboard.setData(ClipboardData(text: _link));
    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Link copied')));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.md, AppSpacing.gutter, 4),
            child: Text('Share tournament', style: Theme.of(context).textTheme.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.xs),
            child: Text(
              _link,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.send_outlined, color: AppColors.primary),
            title: const Text('Send to friends'),
            subtitle: const Text('In a Gamify chat', style: TextStyle(color: AppColors.textSecondary)),
            onTap: () => _sendToFriends(context),
          ),
          ListTile(
            leading: const Icon(Icons.share_outlined, color: AppColors.primary),
            title: const Text('Share to other apps'),
            subtitle: const Text('WhatsApp, Instagram and more', style: TextStyle(color: AppColors.textSecondary)),
            onTap: () => _shareElsewhere(context),
          ),
          ListTile(
            leading: const Icon(Icons.link, color: AppColors.primary),
            title: const Text('Copy link'),
            onTap: () => _copy(context),
          ),
        ],
      ),
    );
  }
}

/// Pick friends and send each of them [message] in their chat. Pops with how many it reached.
class _SendToFriendsScreen extends StatefulWidget {
  final String message;

  const _SendToFriendsScreen({required this.message});

  @override
  State<_SendToFriendsScreen> createState() => _SendToFriendsScreenState();
}

class _SendToFriendsScreenState extends State<_SendToFriendsScreen> {
  Set<int> _selected = {};
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Friends are usually loaded already; this catches anyone added since
    WidgetsBinding.instance.addPostFrameCallback((_) => Provider.of<ConnectionProvider>(context, listen: false).fetchConnections());
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    final chat = Provider.of<ChatProvider>(context, listen: false);
    final results = await Future.wait(_selected.map((id) => chat.sendMessage(id, widget.message)));
    if (!mounted) return;
    final sent = results.where((m) => m != null).length;
    final failed = results.length - sent;
    if (failed > 0) {
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(sent == 0 ? (chat.errorMessage ?? 'Message not sent') : 'Sent to $sent, but $failed didn\'t go through'),
      ));
      if (sent == 0) return;
    }
    Navigator.pop(context, sent);
  }

  @override
  Widget build(BuildContext context) {
    final friends = Provider.of<ConnectionProvider>(context).friends;
    final count = _selected.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Send to friends')),
      body: FriendPicker(
        friends: friends,
        selected: _selected,
        onChanged: (next) => setState(() => _selected = next),
        emptyMessage: 'Add friends from Discover first, then you can send them tournaments.',
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          child: PrimaryButton(
            label: count == 0 ? 'Pick friends' : (count == 1 ? 'Send to 1 friend' : 'Send to $count friends'),
            icon: Icons.send,
            loading: _sending,
            onPressed: count == 0 || _sending ? null : _send,
          ),
        ),
      ),
    );
  }
}
