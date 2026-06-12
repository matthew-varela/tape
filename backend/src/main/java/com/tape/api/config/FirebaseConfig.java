package com.tape.api.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Configuration;

/**
 * Initializes the Firebase Admin SDK once per JVM. Uses
 * {@link GoogleCredentials#getApplicationDefault()}, which picks up
 * {@code GOOGLE_APPLICATION_CREDENTIALS} pointing at the service-account JSON
 * (e.g. {@code /etc/secrets/firebase-service-account.json} on Render).
 */
@Configuration
@ConditionalOnProperty(name = "tape.firebase.enabled", havingValue = "true")
public class FirebaseConfig {

    private static final Logger log = LoggerFactory.getLogger(FirebaseConfig.class);

    @PostConstruct
    public void init() {
        if (!FirebaseApp.getApps().isEmpty()) {
            return;
        }
        try {
            FirebaseOptions options = FirebaseOptions.builder()
                    .setCredentials(GoogleCredentials.getApplicationDefault())
                    .build();
            FirebaseApp.initializeApp(options);
            log.info("Firebase Admin initialized");
        } catch (Exception e) {
            log.error("Firebase Admin failed to initialize", e);
            throw new IllegalStateException("Firebase Admin initialization failed", e);
        }
    }
}
