package com.tape.api.dto;

import jakarta.validation.constraints.NotBlank;

/** Payload for POST /api/blocks — the user to block. */
public record BlockRequest(
    @NotBlank String userId
) {}
