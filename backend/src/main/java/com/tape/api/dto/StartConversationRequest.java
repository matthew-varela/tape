package com.tape.api.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * Payload for POST /api/conversations.
 *
 * The {@code initiatorId} field is accepted for backward compatibility with
 * existing iOS clients but is ignored by the server — the authenticated
 * caller's Firebase UID is always used as the initiator. Both iOS and Android
 * clients may omit it.
 */
public record StartConversationRequest(
    String initiatorId,
    @NotBlank String recipientId
) {}
