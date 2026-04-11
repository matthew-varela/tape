package com.tape.api.dto;

import jakarta.validation.constraints.NotBlank;

public record StartConversationRequest(
    @NotBlank String initiatorId,
    @NotBlank String recipientId
) {}
