package com.tape.api.dto;

import com.tape.api.enums.UserRole;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record SignUpRequest(
    String firebaseUid,
    @NotBlank @Email String email,
    @NotBlank String displayName,
    @NotNull UserRole role
) {}
