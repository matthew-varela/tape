package com.tape.api.dto;

import jakarta.validation.constraints.NotBlank;

/** Payload for POST /api/follows — the user to follow. */
public record FollowRequest(
    @NotBlank String userId
) {}
