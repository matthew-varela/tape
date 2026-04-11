package com.tape.api.dto;

import com.tape.api.enums.VideoCategory;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.util.List;

public record VideoPublishRequest(
    @NotBlank String athleteId,
    @NotBlank String videoUrl,
    String thumbnailUrl,
    @NotNull VideoCategory category,
    List<String> tags,
    String caption
) {}
