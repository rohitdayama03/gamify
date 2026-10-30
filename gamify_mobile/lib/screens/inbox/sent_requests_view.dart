import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time_format.dart';
import '../../models/connection_model.dart';
import '../../providers/connection_provider.dart';
import '../messages/messages_screen.dart';
import '../player/player_profile_screen.dart';
import '../../widgets/player_avatar.dart';

/// Requests the player has sent: pending ones can be cancelled, accepted ones lead to chat.
class SentRequestsView extends StatelessWidget {
  const SentRequestsView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ConnectionProvider>(context);
    final sent = provider.sentInvites;

    return RefreshIndicator(
      onRefresh: provider.fetchConnections,
      child: provider.isLoading && sent.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : sent.isEmpty
          // ListView so pull-to-refresh still works when there is nothing to show
          ? ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              children: const [
                SizedBox(height: 100),
                Icon(
                  Icons.outbox_outlined,
                  size: 64,
                  color: AppColors.textSecondary,
                ),
                SizedBox(height: 12),
                Text(
                  'No sent requests',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Requests you send from Discover show up here until the player answers.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              itemCount: sent.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
              itemBuilder: (_, index) => _SentRequestCard(request: sent[index]),
            ),
    );
  }
}

class _SentRequestCard extends StatelessWidget {
  final ConnectionResponse request;

  const _SentRequestCard({required this.request});

  Future<void> _cancel(BuildContext context) async {
    final name = request.otherPlayer.username;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Cancel request to $name?'),
        content: Text(
          "$name won't see your request any more. You can send a new one later.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Cancel request',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final provider = Provider.of<ConnectionProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await provider.cancelInvite(request.id);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Request to $name cancelled'
              : provider.errorMessage ?? 'Something went wrong',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = Provider.of<ConnectionProvider>(context).isBusy(request.id);
    final player = request.otherPlayer;
    final (label, timeLabel) = switch (request.status) {
      ConnectionStatus.pending => (
        'Pending',
        'Sent ${timeAgo(request.createdAt)}',
      ),
      ConnectionStatus.accepted => (
        'Accepted',
        'Accepted ${timeAgo(request.respondedAt)}',
      ),
      ConnectionStatus.declined => (
        'Declined',
        'Declined ${timeAgo(request.respondedAt)}',
      ),
    };

    return OpenProfileOnTap(
      playerId: player.playerId,
      username: player.username,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  PlayerAvatar(name: player.username, url: player.avatarUrl, radius: 22),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          player.username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          timeLabel,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _StatusTag(label: label, status: request.status),
                ],
              ),
              if (request.status == ConnectionStatus.pending) ...[
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : () => _cancel(context),
                    icon: busy
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.close, size: 18),
                    label: const Text('Cancel request'),
                  ),
                ),
              ] else if (request.status == ConnectionStatus.accepted) ...[
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 44,
                  child: FilledButton.icon(
                    onPressed: () => MessagesScreen.openChat(context, player),
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('Message'),
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

class _StatusTag extends StatelessWidget {
  final String label;
  final ConnectionStatus status;

  const _StatusTag({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ConnectionStatus.pending => AppColors.textPrimary,
      ConnectionStatus.accepted => AppColors.primary,
      ConnectionStatus.declined => AppColors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppFonts.label(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
