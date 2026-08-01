package com.tape.api.controller;

import com.tape.api.dto.*;
import com.tape.api.entity.Conversation;
import com.tape.api.entity.Message;
import com.tape.api.security.SecurityUtils;
import com.tape.api.service.MessageService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/api/conversations")
public class ConversationController {

    private final MessageService messageService;

    public ConversationController(MessageService messageService) {
        this.messageService = messageService;
    }

    /**
     * Returns all conversations for the authenticated caller.
     * The {@code userId} query param is accepted for backward compat with
     * existing iOS clients but the server always uses the token uid.
     */
    @GetMapping
    public List<ConversationResponse> getConversations(
            @RequestParam(required = false) String userId) {
        String uid = SecurityUtils.requireFirebaseUid();
        return messageService.getConversations(uid).stream()
            .map(c -> messageService.toResponse(c, uid))
            .toList();
    }

    /**
     * Creates (or returns existing) a conversation.
     * The initiator id is always the authenticated caller; the
     * {@code initiatorId} body field is accepted but ignored.
     */
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ConversationResponse startConversation(@Valid @RequestBody StartConversationRequest request) {
        String uid = SecurityUtils.requireFirebaseUid();
        Conversation conv = messageService.startConversation(request, uid);
        return messageService.toResponse(conv, uid);
    }

    /** Caller must be a participant in the conversation. */
    @GetMapping("/{id}/messages")
    public List<MessageResponse> getMessages(@PathVariable String id) {
        String uid = SecurityUtils.requireFirebaseUid();
        return messageService.getMessages(id, uid).stream()
            .map(messageService::toResponse)
            .toList();
    }

    /**
     * Marks the other participant's messages in this thread as read. Called
     * when the caller opens the thread. Idempotent — re-reading an already
     * read thread is a no-op.
     */
    @PostMapping("/{id}/read")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void markRead(@PathVariable String id) {
        String uid = SecurityUtils.requireFirebaseUid();
        messageService.markRead(id, uid);
    }

    /**
     * Sends a message. The sender is always the authenticated caller;
     * the {@code senderId} body field is accepted but ignored.
     * Free-tier users are capped at 10 DMs per month.
     */
    @PostMapping("/{id}/messages")
    @ResponseStatus(HttpStatus.CREATED)
    public MessageResponse sendMessage(
            @PathVariable String id,
            @Valid @RequestBody SendMessageRequest request) {
        String uid = SecurityUtils.requireFirebaseUid();
        Message msg = messageService.sendMessage(id, request, uid);
        return messageService.toResponse(msg);
    }
}
