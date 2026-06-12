package com.tape.api.security;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.server.ResponseStatusException;

/** Resolves the authenticated Firebase user id from {@link SecurityContextHolder}. */
public final class SecurityUtils {

    private SecurityUtils() {}

    /**
     * @return Firebase {@code uid} from a verified ID token (see {@link FirebaseAuthenticationToken})
     * @throws ResponseStatusException 401 if there is no authenticated user
     */
    public static String requireFirebaseUid() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated()) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Not authenticated");
        }
        Object principal = auth.getPrincipal();
        if (principal instanceof String uid && !uid.isBlank() && !"anonymousUser".equals(uid)) {
            return uid;
        }
        throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Not authenticated");
    }
}
