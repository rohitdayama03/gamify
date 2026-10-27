package com.example.gamify.notification;

import com.example.gamify.repository.DeviceTokenRepository;
import com.google.firebase.messaging.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionalEventListener;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

/** Delivers {@link PushNotification}s to every phone the recipient is signed in on. */
@Slf4j
@Component
@RequiredArgsConstructor
public class PushNotificationSender {

    // Firebase errors that mean the token will never work again, so it should be forgotten
    private static final Set<MessagingErrorCode> DEAD_TOKEN_ERRORS = Set.of(
            MessagingErrorCode.UNREGISTERED,
            MessagingErrorCode.INVALID_ARGUMENT,
            MessagingErrorCode.SENDER_ID_MISMATCH
    );

    private final FirebaseMessagingProvider firebase;
    private final DeviceTokenRepository deviceTokenRepository;

    // After commit, so nobody is notified about a message or request that was rolled back; async, so the
    // API response never waits on Firebase
    @Async
    @TransactionalEventListener(fallbackExecution = true)
    public void send(PushNotification notification) {
        FirebaseMessaging messaging = firebase.messaging().orElse(null);
        if (messaging == null) {
            return;
        }
        List<String> tokens = deviceTokenRepository.findTokensByPlayerId(notification.recipientId());
        if (tokens.isEmpty()) {
            return;
        }

        List<Message> messages = tokens.stream().map(token -> toMessage(token, notification)).toList();
        try {
            BatchResponse result = messaging.sendEach(messages);
            List<String> deadTokens = new ArrayList<>();
            for (int i = 0; i < result.getResponses().size(); i++) {
                SendResponse response = result.getResponses().get(i);
                if (!response.isSuccessful()) {
                    FirebaseMessagingException error = response.getException();
                    if (error != null && DEAD_TOKEN_ERRORS.contains(error.getMessagingErrorCode())) {
                        deadTokens.add(tokens.get(i));
                    } else {
                        log.warn("Push to player {} failed: {}", notification.recipientId(), error == null ? "unknown" : error.getMessage());
                    }
                }
            }
            if (!deadTokens.isEmpty()) {
                deviceTokenRepository.deleteByTokens(deadTokens);
            }
        } catch (FirebaseMessagingException e) {
            log.warn("Push to player {} failed: {}", notification.recipientId(), e.getMessage());
        }
    }

    // Stored tokens are Firebase Installation IDs (the app registers with FCM direct send)
    private static Message toMessage(String installationId, PushNotification notification) {
        return Message.builder()
                .setFid(installationId)
                .setNotification(Notification.builder()
                        .setTitle(notification.title())
                        .setBody(notification.body())
                        .build())
                .putAllData(notification.data())
                .setAndroidConfig(AndroidConfig.builder()
                        .setPriority(AndroidConfig.Priority.HIGH)
                        .setNotification(AndroidNotification.builder()
                                .setChannelId(notification.channel())
                                .setTag(notification.tag())
                                .build())
                        .build())
                .build();
    }
}
