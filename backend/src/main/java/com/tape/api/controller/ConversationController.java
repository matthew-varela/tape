package com.tape.api.controller;

import com.tape.api.dto.*;
import com.tape.api.entity.Conversation;
import com.tape.api.entity.Message;
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

    @GetMapping
    public List<ConversationResponse> getConversations(@RequestParam String userId) {
        return messageService.getConversations(userId).stream()
            .map(c -> messageService.toResponse(c, userId))
            .toList();
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ConversationResponse startConversation(@Valid @RequestBody StartConversationRequest request) {
        Conversation conv = messageService.startConversation(request);
        return messageService.toResponse(conv, request.initiatorId());
    }

    @GetMapping("/{id}/messages")
    public List<MessageResponse> getMessages(@PathVariable String id) {
        return messageService.getMessages(id).stream()
            .map(messageService::toResponse)
            .toList();
    }

    @PostMapping("/{id}/messages")
    @ResponseStatus(HttpStatus.CREATED)
    public MessageResponse sendMessage(@PathVariable String id, @Valid @RequestBody SendMessageRequest request) {
        Message msg = messageService.sendMessage(id, request);
        return messageService.toResponse(msg);
    }
}
