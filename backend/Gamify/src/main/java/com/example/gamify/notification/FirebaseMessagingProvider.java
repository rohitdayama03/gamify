package com.example.gamify.notification;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.auth.oauth2.ServiceAccountCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.io.ByteArrayInputStream;
import java.io.FileInputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.Optional;

/**
 * Connects to Firebase with the service account from FIREBASE_SERVICE_ACCOUNT (the JSON itself, as on the server)
 * or FIREBASE_SERVICE_ACCOUNT_FILE (a path, handy locally). Without either, push notifications are switched off
 * and the rest of the app works as usual.
 */
@Slf4j
@Component
public class FirebaseMessagingProvider {

    private static final String APP_NAME = "gamify";

    private final FirebaseMessaging messaging;

    public FirebaseMessagingProvider(
            @Value("${app.firebase.service-account:}") String serviceAccountJson,
            @Value("${app.firebase.service-account-file:}") String serviceAccountFile) {
        this.messaging = connect(serviceAccountJson, serviceAccountFile);
    }

    public Optional<FirebaseMessaging> messaging() {
        return Optional.ofNullable(messaging);
    }

    private static FirebaseMessaging connect(String json, String file) {
        if (json.isBlank() && file.isBlank()) {
            log.warn("Push notifications are off: set FIREBASE_SERVICE_ACCOUNT or FIREBASE_SERVICE_ACCOUNT_FILE to enable them");
            return null;
        }
        try (InputStream credentials = json.isBlank()
                ? new FileInputStream(file)
                : new ByteArrayInputStream(json.getBytes(StandardCharsets.UTF_8))) {
            GoogleCredentials googleCredentials = GoogleCredentials.fromStream(credentials);
            String projectId = googleCredentials instanceof ServiceAccountCredentials account ? account.getProjectId() : null;
            FirebaseOptions options = FirebaseOptions.builder()
                    .setCredentials(googleCredentials)
                    .setProjectId(projectId)
                    .build();
            // Reuse the app if it already exists (e.g. after a dev-tools restart in the same JVM)
            FirebaseApp app = FirebaseApp.getApps().stream()
                    .filter(a -> a.getName().equals(APP_NAME))
                    .findFirst()
                    .orElseGet(() -> FirebaseApp.initializeApp(options, APP_NAME));
            log.info("Push notifications are on (Firebase project {})", app.getOptions().getProjectId());
            return FirebaseMessaging.getInstance(app);
        } catch (Exception e) {
            // A bad key shouldn't stop the server; it just means no pushes
            log.error("Push notifications are off: could not load the Firebase service account ({})", e.getMessage());
            return null;
        }
    }
}
