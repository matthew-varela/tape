package com.tape.api.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * Payload for POST /api/conversations/{id}/messages.
 *
 * The {@code senderId} field is accepted for backward compatibility with
 * existing iOS clients but is ignored by the server — the authenticated
 * caller's Firebase UID is always used as the sender. Both iOS and Android
 * clients may omit it.
 */
public record SendMessageRequest(
    String senderId,
    @NotBlank String text
) {}
