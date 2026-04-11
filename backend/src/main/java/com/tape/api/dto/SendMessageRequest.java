package com.tape.api.dto;

import jakarta.validation.constraints.NotBlank;

public record SendMessageRequest(
    @NotBlank String senderId,
    @NotBlank String text
) {}
