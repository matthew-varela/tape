package com.tape.api.security;

import com.google.firebase.auth.FirebaseToken;
import java.util.Collections;
import org.springframework.security.authentication.AbstractAuthenticationToken;

/**
 * Spring Security authentication representing a verified Firebase ID token.
 * The {@linkplain #getPrincipal() principal} is the Firebase {@code uid}.
 */
public class FirebaseAuthenticationToken extends AbstractAuthenticationToken {

    private final FirebaseToken firebaseToken;

    public FirebaseAuthenticationToken(FirebaseToken firebaseToken) {
        super(Collections.emptyList());
        this.firebaseToken = firebaseToken;
        setAuthenticated(true);
    }

    @Override
    public Object getCredentials() {
        return null;
    }

    @Override
    public Object getPrincipal() {
        return firebaseToken.getUid();
    }

    public FirebaseToken getFirebaseToken() {
        return firebaseToken;
    }
}
