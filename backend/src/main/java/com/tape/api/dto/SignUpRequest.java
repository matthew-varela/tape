package com.tape.api.dto;

import com.tape.api.enums.UserRole;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Past;
import java.time.LocalDate;

/**
 * Payload for POST /api/auth/signup.
 *
 * The server derives the user id from the verified Firebase Bearer token;
 * the legacy {@code firebaseUid} body field is accepted but ignored so
 * existing iOS clients do not break.
 *
 * {@code dateOfBirth} (ISO {@code yyyy-MM-dd}) is required for age gating; the
 * minimum-age rule is enforced in {@code UserService.createUser}.
 */
public record SignUpRequest(
    String firebaseUid,
    String email,
    @NotBlank String displayName,
    @NotNull UserRole role,
    @NotNull @Past LocalDate dateOfBirth
) {}
