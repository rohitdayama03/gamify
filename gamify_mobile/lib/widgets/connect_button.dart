import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../models/connection_model.dart';
import '../models/player_model.dart';
import '../providers/connection_provider.dart';
import '../screens/messages/messages_screen.dart';

/// The one action that fits how you relate to [player]: connect, accept, pending, message or declined.
/// [fullWidth] is the large profile-page version; the compact one sits on Discover cards.
class ConnectButton extends StatelessWidget {
  final PlayerResponse player;
  final bool fullWidth;

  const ConnectButton({super.key, required this.player, this.fullWidth = false});

  Future<void> _run(BuildContext context, Future<bool> Function(ConnectionProvider) action, String successMessage) async {
    final provider = Provider.of<ConnectionProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await action(provider);
    messenger.showSnackBar(SnackBar(content: Text(ok ? successMessage : provider.errorMessage ?? 'Something went wrong')));
  }

  Future<void> _cancel(BuildContext context, ConnectionResponse request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Cancel request to ${player.username}?'),
        content: Text("${player.username} won't see your request any more. You can send a new one later."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep it')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel request', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await _run(context, (p) => p.cancelInvite(request.id), 'Request to ${player.username} cancelled');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ConnectionProvider>(context);
    final busy = provider.isInviting(player.playerId);

    switch (provider.statusWith(player.playerId)) {
      case RelationStatus.none:
        return _button(
          icon: Icons.person_add_alt_1,
          label: fullWidth ? 'Send request' : 'Connect',
          primary: true,
          busy: busy,
          onPressed: () => _run(context, (p) => p.sendInvite(player.playerId), 'Request sent to ${player.username}'),
        );
      case RelationStatus.inviteReceived:
        final invite = provider.pendingInviteFrom(player.playerId)!;
        return _button(
          icon: Icons.check,
          label: 'Accept request',
          primary: true,
          busy: provider.isBusy(invite.id),
          onPressed: () => _run(context, (p) => p.acceptInvite(invite.id), 'You and ${player.username} are now friends'),
        );
      case RelationStatus.inviteSent:
        final request = provider.pendingInviteTo(player.playerId);
        if (!fullWidth || request == null) return _button(icon: Icons.schedule, label: 'Pending');
        return Row(
          children: [
            Expanded(child: _button(icon: Icons.schedule, label: 'Request pending')),
            const SizedBox(width: 8),
            TextButton(
              onPressed: provider.isBusy(request.id) ? null : () => _cancel(context, request),
              child: const Text('Cancel'),
            ),
          ],
        );
      case RelationStatus.friends:
        return _button(
          icon: Icons.chat_bubble_outline,
          label: 'Message',
          primary: true,
          onPressed: () => MessagesScreen.openChat(
            context,
            PlayerSummary(
              playerId: player.playerId,
              username: player.username,
              avatarUrl: player.avatarUrl,
              playerBio: player.playerBio,
              country: player.country,
              language: player.language,
            ),
          ),
        );
      case RelationStatus.declined:
        return _button(icon: Icons.block, label: 'Request declined');
    }
  }

  // Without onPressed the button renders disabled, used for the read-only states
  Widget _button({required IconData icon, required String label, bool primary = false, bool busy = false, VoidCallback? onPressed}) {
    final iconWidget = busy
        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
        : Icon(icon, size: 18);
    final action = busy ? null : onPressed;

    if (fullWidth) {
      return SizedBox(
        height: 48,
        width: double.infinity,
        child: primary
            ? FilledButton.icon(onPressed: action, icon: iconWidget, label: Text(label))
            : OutlinedButton.icon(onPressed: action, icon: iconWidget, label: Text(label)),
      );
    }
    return SizedBox(
      height: 36,
      child: OutlinedButton.icon(
        onPressed: action,
        icon: iconWidget,
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(44, 36),
          side: onPressed != null ? const BorderSide(color: AppColors.primary) : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
        ),
      ),
    );
  }
}
