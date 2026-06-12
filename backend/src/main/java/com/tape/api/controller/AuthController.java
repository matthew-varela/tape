package com.tape.api.controller;

import com.tape.api.dto.SignUpRequest;
import com.tape.api.entity.User;
import com.tape.api.security.SecurityUtils;
import com.tape.api.service.UserService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

/**
 * Handles account creation and sign-in.
 *
 * Both endpoints are backed by the verified Firebase Bearer token — the server
 * derives the caller's identity from the token uid, never from body fields.
 * This keeps the auth contract identical for iOS and future Android clients.
 */
@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final UserService userService;

    public AuthController(UserService userService) {
        this.userService = userService;
    }

    /**
     * Creates a new User record keyed to the caller's Firebase UID.
     * The legacy {@code firebaseUid} body field is ignored; the token is
     * the authority. Returns 409 if a record already exists.
     */
    @PostMapping("/signup")
    @ResponseStatus(HttpStatus.CREATED)
    public User signUp(@Valid @RequestBody SignUpRequest request) {
        String uid = SecurityUtils.requireFirebaseUid();
        return userService.createUser(uid, request);
    }

    /**
     * Returns the caller's existing User record. Returns 404 if the caller
     * has not signed up yet (client should call /signup first).
     * The {@code email} body field is accepted for backward compatibility
     * with existing iOS clients but is not used for lookup.
     */
    @PostMapping("/signin")
    public User signIn(@RequestBody(required = false) java.util.Map<String, String> body) {
        String uid = SecurityUtils.requireFirebaseUid();
        return userService.getUser(uid);
    }
}
