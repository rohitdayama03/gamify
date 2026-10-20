import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/chat_provider.dart';
import '../../providers/connection_provider.dart';
import '../home/home_screen.dart';
import '../messages/messages_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const int _messagesTab = 1;
  static const int _notificationsTab = 2;
  static const int _profileTab = 3;
  // How often to check for new messages and invites so the badges stay current
  static const Duration _refreshInterval = Duration(seconds: 15);
  int _currentIndex = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => _refresh());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _refresh() {
    Provider.of<ConnectionProvider>(context, listen: false).fetchConnections();
    Provider.of<ChatProvider>(context, listen: false).fetchConversations();
  }

  void _selectTab(int index) {
    setState(() => _currentIndex = index);
    // Pick up messages and invites received since the last load
    if (index == _messagesTab) {
      Provider.of<ChatProvider>(context, listen: false).fetchConversations();
    } else if (index == _notificationsTab) {
      Provider.of<ConnectionProvider>(context, listen: false).fetchConnections();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = Provider.of<ConnectionProvider>(context).pendingInvites.length;
    final unreadCount = Provider.of<ChatProvider>(context).totalUnread;

    return Scaffold(
      // IndexedStack keeps each tab's state (search results, scroll position) when switching
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(onAvatarTap: () => _selectTab(_profileTab)),
          const MessagesScreen(),
          const NotificationsScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _selectTab,
        backgroundColor: AppColors.cardBackground,
        indicatorColor: AppColors.primary.withValues(alpha: 0.25),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text('$unreadCount'),
              child: const Icon(Icons.chat_bubble_outline),
            ),
            selectedIcon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text('$unreadCount'),
              child: const Icon(Icons.chat_bubble),
            ),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: pendingCount > 0,
              label: Text('$pendingCount'),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: pendingCount > 0,
              label: Text('$pendingCount'),
              child: const Icon(Icons.notifications),
            ),
            label: 'Notifications',
          ),
          const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
