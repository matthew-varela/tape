package com.tape.api.service;

import com.google.firebase.FirebaseApp;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseAuthException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * Deletes the Firebase Authentication user behind an account so that account
 * deletion is complete (the email can be reused and no orphan auth record
 * lingers).
 *
 * Works in both modes: when Firebase is disabled locally / in tests, no
 * {@link FirebaseApp} is initialized and this becomes a safe no-op. Auth-user
 * deletion failures are logged but never fail the request, because the
 * application database rows have already been removed by the time this runs.
 */
@Service
public class FirebaseAccountService {

    private static final Logger log = LoggerFactory.getLogger(FirebaseAccountService.class);

    public void deleteUser(String uid) {
        if (FirebaseApp.getApps().isEmpty()) {
            log.info("Firebase not initialized; skipping auth-user deletion for uid={}", uid);
            return;
        }
        try {
            FirebaseAuth.getInstance().deleteUser(uid);
            log.info("Deleted Firebase auth user uid={}", uid);
        } catch (FirebaseAuthException e) {
            log.warn("Failed to delete Firebase auth user uid={}: {}", uid, e.getMessage());
        }
    }
}
