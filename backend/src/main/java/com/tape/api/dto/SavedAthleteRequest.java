package com.tape.api.dto;

import jakarta.validation.constraints.NotBlank;

/** Payload for POST /api/saved-athletes — the athlete to shortlist. */
public record SavedAthleteRequest(
    @NotBlank String athleteId
) {}
