package com.tape.api.dto;

import com.tape.api.enums.ReportTargetType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/**
 * Payload for POST /api/reports.
 *
 * {@code details} is optional free text the reporter can add. The reporter's
 * identity always comes from the verified token, never the request body.
 */
public record ReportRequest(
    @NotNull ReportTargetType targetType,
    @NotBlank String targetId,
    @NotBlank String reason,
    String details
) {}
