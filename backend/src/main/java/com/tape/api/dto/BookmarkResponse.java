package com.tape.api.dto;

import java.util.List;

/** Response for GET /api/users/{id}/bookmarks */
public record BookmarkResponse(List<String> videoIds) {}
