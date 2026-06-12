package com.tape.api.dto;

import com.tape.api.enums.UserRole;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/**
 * Payload for POST /api/auth/signup.
 *
 * The server derives the user id from the verified Firebase Bearer token;
 * the legacy {@code firebaseUid} body field is accepted but ignored so
 * existing iOS clients do not break.
 */
public record SignUpRequest(
    String firebaseUid,
    String email,
    @NotBlank String displayName,
    @NotNull UserRole role
) {}
