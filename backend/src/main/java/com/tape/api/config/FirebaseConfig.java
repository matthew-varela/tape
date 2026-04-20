package com.tape.api.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;

@Configuration
public class FirebaseConfig {

    @Value("${firebase.credentials:}")
    private String firebaseCredentials;

    @PostConstruct
    public void init() throws IOException {
        if (FirebaseApp.getApps().isEmpty()) {
            if (firebaseCredentials != null && !firebaseCredentials.isBlank()) {
                FirebaseOptions options = FirebaseOptions.builder()
                    .setCredentials(GoogleCredentials.fromStream(
                        new ByteArrayInputStream(firebaseCredentials.getBytes(StandardCharsets.UTF_8))
                    ))
                    .build();
                FirebaseApp.initializeApp(options);
                System.out.println("Firebase initialized with service account credentials");
            } else {
                System.out.println("WARNING: No FIREBASE_CREDENTIALS set -- Firebase auth verification disabled");
            }
        }
    }
}
