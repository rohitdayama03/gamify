import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/chat_provider.dart';
import '../../providers/connection_provider.dart';
import '../messages/messages_screen.dart';
import '../notifications/notifications_screen.dart';
import 'sent_requests_view.dart';

/// Inbox tab: Chats | Requests, where Requests splits into Received | Sent (PRD §2, §7.1).
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  static const int chatsTab = 0;
  static const int requestsTab = 1;

  @override
  State<InboxScreen> createState() => InboxScreenState();
}

class InboxScreenState extends State<InboxScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  bool _showSent = false;

  void showTab(int index) => _tabs.animateTo(index);

  /// Opens Requests on the Received or Sent list
  void showRequests({bool sent = false}) {
    _tabs.animateTo(InboxScreen.requestsTab);
    setState(() => _showSent = sent);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unread = Provider.of<ChatProvider>(context).totalUnread;
    final connections = Provider.of<ConnectionProvider>(context);
    final received = connections.pendingInvites.length;
    final sentPending = connections.pendingSentCount;

    return Column(
      children: [
        TabBar(
          controller: _tabs,
          tabs: [
            Tab(
              child: _TabLabel(label: 'Chats', count: unread),
            ),
            Tab(
              child: _TabLabel(label: 'Requests', count: received),
            ),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              const MessagesScreen(),
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.gutter,
                      AppSpacing.sm,
                      AppSpacing.gutter,
                      0,
                    ),
                    child: _SegmentSwitch(
                      labels: [
                        'Received ($received)',
                        'Sent ($sentPending pending)',
                      ],
                      selected: _showSent ? 1 : 0,
                      onChanged: (index) =>
                          setState(() => _showSent = index == 1),
                    ),
                  ),
                  Expanded(
                    child: _showSent
                        ? const SentRequestsView()
                        : const NotificationsScreen(embedded: true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TabLabel extends StatelessWidget {
  final String label;
  final int count;

  const _TabLabel({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Badge(label: Text('$count')),
        ],
      ],
    );
  }
}

/// Two-option toggle in the terminal style: the active side is a solid mint block.
class _SegmentSwitch extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  const _SegmentSwitch({
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selected,
                child: InkWell(
                  onTap: () => onChanged(i),
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  child: AnimatedContainer(
                    duration: AppMotion.of(context, AppMotion.fast),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == selected
                          ? AppColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.input - 1),
                    ),
                    child: Text(
                      labels[i].toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.label(
                        fontSize: 11.5,
                        color: i == selected
                            ? AppColors.onPrimary
                            : AppColors.textSecondary,
                        fontWeight: i == selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ).copyWith(letterSpacing: 0.6),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
