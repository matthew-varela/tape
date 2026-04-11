package com.tape.api.dto;

import com.tape.api.enums.UserRole;
import java.time.Instant;
import java.util.List;
import java.util.Map;

public record ConversationResponse(
    String id,
    List<String> participantIds,
    Map<String, String> participantNames,
    Map<String, String> participantImageUrls,
    String lastMessage,
    Instant lastMessageDate,
    long unreadCount,
    UserRole initiatedByRole
) {}
