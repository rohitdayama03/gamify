package com.example.gamify.notification;

import java.util.Map;

/**
 * A push notification for one player, published as an application event and sent once the
 * surrounding transaction commits.
 *
 * @param channel Android notification channel the app created ("messages", "requests" or "activity")
 * @param tag     notifications with the same tag replace each other on the phone (e.g. one per chat)
 * @param data    extra values the app uses to open the right screen when the notification is tapped
 */
public record PushNotification(
        Long recipientId,
        String title,
        String body,
        String channel,
        String tag,
        Map<String, String> data
) {
    public static final String CHANNEL_MESSAGES = "messages";
    public static final String CHANNEL_REQUESTS = "requests";
    public static final String CHANNEL_ACTIVITY = "activity";
}
