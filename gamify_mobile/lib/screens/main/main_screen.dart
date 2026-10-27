import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/notifications/push_notifications.dart';
import '../../models/game.dart';
import '../../providers/chat_provider.dart';
import '../../providers/connection_provider.dart';
import '../../widgets/app_logo.dart';
import '../discover/discover_screen.dart';
import '../home/home_screen.dart';
import '../inbox/inbox_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';
import '../settings/settings_screen.dart';

/// App shell: top bar (logo + notifications) and bottom nav Home | Discover | Inbox | Profile (PRD §2).
class MainScreen extends StatefulWidget {
  static const int homeTab = 0;
  static const int discoverTab = 1;
  static const int inboxTab = 2;
  static const int profileTab = 3;

  final int initialTab;

  const MainScreen({super.key, this.initialTab = homeTab});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // How often to check for new messages and requests so the badges stay current
  static const Duration _refreshInterval = Duration(seconds: 15);
  final _discoverKey = GlobalKey<DiscoverScreenState>();
  late int _currentIndex = widget.initialTab;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => _refresh());
    // Signed in: register this phone for pushes; a push arriving while open refreshes badges right away
    PushNotifications.instance.start(onActivity: () {
      if (mounted) _refresh();
    });
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
    // Pick up messages and requests received since the last load
    if (index == MainScreen.inboxTab) _refresh();
  }

  void _findPlayers(Game game) {
    _selectTab(MainScreen.discoverTab);
    _discoverKey.currentState?.selectGame(game);
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = Provider.of<ConnectionProvider>(context)
        .pendingInvites
        .length;
    final unreadCount = Provider.of<ChatProvider>(context).totalUnread;
    final inboxCount = pendingCount + unreadCount;

    return PopScope(
      // Back from another tab returns to Home before leaving the app
      canPop: _currentIndex == MainScreen.homeTab,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _selectTab(MainScreen.homeTab);
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: AppSpacing.gutter,
          title: const AppLogo(size: 18),
          actions: [
            IconButton(
              tooltip: pendingCount > 0
                  ? 'Notifications, $pendingCount new'
                  : 'Notifications',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
              icon: Badge(
                isLabelVisible: pendingCount > 0,
                label: Text('$pendingCount'),
                child: const Icon(Icons.notifications_outlined),
              ),
            ),
            if (_currentIndex == MainScreen.profileTab)
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            const SizedBox(width: AppSpacing.xs),
          ],
        ),
        // IndexedStack keeps each tab's state (search results, scroll position) when switching
        body: IndexedStack(
          index: _currentIndex,
          children: [
            HomeScreen(
              onFindPlayers: _findPlayers,
            ),
            DiscoverScreen(key: _discoverKey),
            const InboxScreen(),
            const ProfileScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _selectTab,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            const NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: 'Discover',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: inboxCount > 0,
                label: Text('$inboxCount'),
                child: const Icon(Icons.inbox_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: inboxCount > 0,
                label: Text('$inboxCount'),
                child: const Icon(Icons.inbox),
              ),
              label: 'Inbox',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
