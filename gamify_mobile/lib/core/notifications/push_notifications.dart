import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../models/connection_model.dart';
import '../../screens/messages/chat_screen.dart';
import '../../screens/notifications/notifications_screen.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';

/// Push notifications for new messages and requests (Firebase Cloud Messaging, Android only for now).
///
/// When the app is in the background or closed, Android shows the notification itself. While it's open,
/// [_onForegroundMessage] shows it, except for the chat already on screen. Tapping one opens the chat
/// or the requests list.
class PushNotifications {
  PushNotifications._();

  static final PushNotifications instance = PushNotifications._();

  /// Lets a notification tap open a screen without a BuildContext; set on the MaterialApp.
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// The friend whose chat is open, so their messages don't also pop up as notifications.
  static int? openChatPlayerId;

  // Must match the channels the backend sends to (PushNotification.CHANNEL_*)
  static const AndroidNotificationChannel _messagesChannel = AndroidNotificationChannel(
    'messages',
    'Messages',
    description: 'New chat messages from your friends',
    importance: Importance.high,
  );
  static const AndroidNotificationChannel _requestsChannel = AndroidNotificationChannel(
    'requests',
    'Requests',
    description: 'Friend requests you receive and requests that are accepted',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _ready = false;
  // This phone's Firebase Installation ID: what the backend sends pushes to
  String? _installationId;
  VoidCallback? _onActivity;

  // iOS also needs an Apple push key, which isn't set up yet
  bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Call once before runApp. Failures are logged and leave the app working without pushes.
  Future<void> init() async {
    if (!_supported || _ready) return;
    try {
      await Firebase.initializeApp();
      await _local.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('ic_notification')),
        onDidReceiveNotificationResponse: (response) => _openFromPayload(response.payload),
      );
      final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(_messagesChannel);
      await android?.createNotificationChannel(_requestsChannel);
      _ready = true;
    } catch (e) {
      debugPrint('Push notifications unavailable: $e');
    }
  }

  /// Call once signed in: asks permission, registers this phone with the backend and starts listening.
  /// [onActivity] runs when a notification arrives while the app is open, e.g. to refresh badges.
  Future<void> start({required VoidCallback onActivity}) async {
    if (!_ready) return;
    _onActivity = onActivity;
    final messaging = FirebaseMessaging.instance;
    try {
      // Shows the Android 13+ permission prompt the first time; later calls return the saved answer
      await messaging.requestPermission();

      _cancelSubscriptions();
      _subscriptions
        // Fires once registration completes, and again if Firebase ever rotates the ID
        ..add(messaging.onRegistered.listen((installationId) {
          _installationId = installationId;
          _register(installationId);
        }))
        ..add(FirebaseMessaging.onMessage.listen(_onForegroundMessage))
        ..add(FirebaseMessaging.onMessageOpenedApp.listen((message) => _openFromData(message.data)));
      await messaging.register();

      // The app was launched by tapping a notification while it was closed
      final initial = await messaging.getInitialMessage();
      if (initial != null) _openFromData(initial.data);
    } catch (e) {
      debugPrint('Could not start push notifications: $e');
    }
  }

  /// Call on logout, while the login token is still valid, so this phone stops getting the player's pushes.
  Future<void> stop() async {
    if (!_ready) return;
    _cancelSubscriptions();
    _onActivity = null;
    final installationId = _installationId;
    _installationId = null;
    if (installationId == null) return;
    try {
      await ApiClient().dio.post(ApiEndpoints.unregisterDevice, data: {'token': installationId, 'platform': 'android'});
    } catch (e) {
      debugPrint('Could not unregister this device: $e');
    }
    try {
      // Stop Firebase delivering to this phone until the next sign-in registers it again
      await FirebaseMessaging.instance.unregister();
    } catch (_) {}
  }

  /// Clears the notification for a chat once it's opened in the app.
  Future<void> clearChat(int playerId) async {
    if (!_ready) return;
    await _local.cancel(id: 0, tag: 'chat-$playerId');
  }

  Future<void> _register(String installationId) async {
    try {
      await ApiClient().dio.post(ApiEndpoints.devices, data: {'token': installationId, 'platform': 'android'});
    } catch (e) {
      debugPrint('Could not register this device for notifications: $e');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    _onActivity?.call();
    final data = message.data;
    final notification = message.notification;
    if (notification == null) return;
    // Already reading this chat; the new message appears there
    if (data['type'] == 'message' && int.tryParse('${data['playerId']}') == openChatPlayerId) return;

    final channel = notification.android?.channelId == _requestsChannel.id ? _requestsChannel : _messagesChannel;
    _local.show(
      id: 0,
      title: notification.title,
      body: notification.body,
      payload: jsonEncode(data),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notification',
          color: const Color(0xFF4AF2A1),
          // Same tag as the backend uses, so a newer message replaces the older one
          tag: notification.android?.tag,
        ),
      ),
    );
  }

  void _openFromPayload(String? payload) {
    if (payload == null) return;
    try {
      _openFromData(Map<String, dynamic>.from(jsonDecode(payload) as Map));
    } catch (_) {}
  }

  void _openFromData(Map<String, dynamic> data) {
    // Wait for the first frame so the navigator exists when launched from a notification
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = navigatorKey.currentState;
      if (navigator == null) return;
      final playerId = int.tryParse('${data['playerId']}');
      final username = '${data['username'] ?? ''}';
      switch (data['type']) {
        case 'message':
        case 'request_accepted':
          if (playerId == null) return;
          navigator.push(MaterialPageRoute(
            builder: (_) => ChatScreen(friend: PlayerSummary(playerId: playerId, username: username)),
          ));
        case 'request_received':
          navigator.push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
      }
    });
  }

  void _cancelSubscriptions() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }
}
