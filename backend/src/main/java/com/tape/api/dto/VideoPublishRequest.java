package com.tape.api.dto;

import com.tape.api.enums.VideoCategory;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.util.List;

/**
 * Payload for POST /api/videos.
 *
 * The {@code athleteId} field is accepted for backward compatibility with
 * existing iOS clients but is ignored by the server — the authenticated
 * caller's Firebase UID is used as the athlete id. Both iOS and Android
 * clients may omit it.
 */
public record VideoPublishRequest(
    String athleteId,
    @NotBlank String videoUrl,
    String thumbnailUrl,
    @NotNull VideoCategory category,
    List<String> tags,
    String caption
) {}
