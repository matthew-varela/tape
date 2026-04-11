package com.tape.api.dto;

import com.tape.api.enums.VideoCategory;
import java.time.Instant;
import java.util.List;

public record VideoFeedResponse(
    String id,
    String athleteId,
    String videoUrl,
    String thumbnailUrl,
    VideoCategory category,
    List<String> tags,
    String caption,
    Instant createdAt,
    boolean isPinned,
    String athleteName,
    String athleteSchool,
    int athleteGradYear,
    String athletePosition,
    String athleteProfileImageUrl
) {}
