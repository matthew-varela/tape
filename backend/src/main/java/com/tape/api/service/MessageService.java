package com.tape.api.service;

import com.tape.api.dto.ConversationResponse;
import com.tape.api.dto.MessageResponse;
import com.tape.api.dto.SendMessageRequest;
import com.tape.api.dto.StartConversationRequest;
import com.tape.api.entity.Conversation;
import com.tape.api.entity.Message;
import com.tape.api.entity.User;
import com.tape.api.repository.ConversationRepository;
import com.tape.api.repository.MessageRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import java.time.Instant;
import java.util.List;
import java.util.Map;

@Service
public class MessageService {

    private final ConversationRepository conversationRepo;
    private final MessageRepository messageRepo;
    private final UserService userService;

    public MessageService(ConversationRepository conversationRepo, MessageRepository messageRepo, UserService userService) {
        this.conversationRepo = conversationRepo;
        this.messageRepo = messageRepo;
        this.userService = userService;
    }

    public List<Conversation> getConversations(String userId) {
        return conversationRepo.findByParticipant(userId);
    }

    @Transactional
    public Conversation startConversation(StartConversationRequest req) {
        return conversationRepo.findByParticipants(req.initiatorId(), req.recipientId())
            .orElseGet(() -> {
                User initiator = userService.getUser(req.initiatorId());
                User recipient = userService.getUser(req.recipientId());

                if (initiator.getRole() == com.tape.api.enums.UserRole.ATHLETE) {
                    throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Athletes cannot initiate conversations");
                }

                Conversation conv = new Conversation();
                conv.setParticipant1(initiator);
                conv.setParticipant2(recipient);
                conv.setInitiatedByRole(initiator.getRole());
                return conversationRepo.save(conv);
            });
    }

    public List<Message> getMessages(String conversationId) {
        return messageRepo.findByConversationIdOrderBySentAtAsc(conversationId);
    }

    @Transactional
    public Message sendMessage(String conversationId, SendMessageRequest req) {
        Conversation conv = conversationRepo.findById(conversationId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Conversation not found"));

        if (!conv.hasParticipant(req.senderId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "User is not a participant");
        }

        User sender = userService.getUser(req.senderId());
        Message msg = new Message();
        msg.setConversation(conv);
        msg.setSender(sender);
        msg.setText(req.text());
        Message saved = messageRepo.save(msg);

        conv.setLastMessage(req.text());
        conv.setLastMessageDate(Instant.now());
        conversationRepo.save(conv);

        return saved;
    }

    public ConversationResponse toResponse(Conversation c, String currentUserId) {
        User p1 = c.getParticipant1();
        User p2 = c.getParticipant2();
        long unread = messageRepo.countByConversationIdAndIsReadFalseAndSenderIdNot(c.getId(), currentUserId);

        return new ConversationResponse(
            c.getId(),
            List.of(p1.getId(), p2.getId()),
            Map.of(p1.getId(), p1.getDisplayName(), p2.getId(), p2.getDisplayName()),
            Map.of(p1.getId(), p1.getProfileImageUrl() != null ? p1.getProfileImageUrl() : "",
                   p2.getId(), p2.getProfileImageUrl() != null ? p2.getProfileImageUrl() : ""),
            c.getLastMessage(),
            c.getLastMessageDate(),
            unread,
            c.getInitiatedByRole()
        );
    }

    public MessageResponse toResponse(Message m) {
        return new MessageResponse(
            m.getId(),
            m.getConversation().getId(),
            m.getSender().getId(),
            m.getText(),
            m.getSentAt(),
            m.isRead()
        );
    }
}
