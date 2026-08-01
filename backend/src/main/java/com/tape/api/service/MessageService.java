package com.tape.api.service;

import com.tape.api.dto.ConversationResponse;
import com.tape.api.dto.MessageResponse;
import com.tape.api.dto.SendMessageRequest;
import com.tape.api.dto.StartConversationRequest;
import com.tape.api.entity.Conversation;
import com.tape.api.entity.Message;
import com.tape.api.entity.User;
import com.tape.api.enums.SubscriptionTier;
import com.tape.api.repository.ConversationRepository;
import com.tape.api.repository.MessageRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;

@Service
public class MessageService {

    /** Free-tier monthly DM cap. */
    private static final int FREE_DM_MONTHLY_CAP = 10;

    private final ConversationRepository conversationRepo;
    private final MessageRepository messageRepo;
    private final UserService userService;
    private final ModerationService moderationService;

    public MessageService(ConversationRepository conversationRepo,
                          MessageRepository messageRepo,
                          UserService userService,
                          ModerationService moderationService) {
        this.conversationRepo = conversationRepo;
        this.messageRepo = messageRepo;
        this.userService = userService;
        this.moderationService = moderationService;
    }

    public List<Conversation> getConversations(String callerUid) {
        Set<String> hidden = moderationService.getHiddenUserIds(callerUid);
        return conversationRepo.findByParticipant(callerUid).stream()
            .filter(c -> !hidden.contains(c.otherParticipant(callerUid).getId()))
            .toList();
    }

    /**
     * Creates (or returns the existing) thread. Athletes cannot initiate.
     * The initiator id comes from the verified token, not the request body.
     */
    @Transactional
    public Conversation startConversation(StartConversationRequest req, String callerUid) {
        if (moderationService.isEitherBlocked(callerUid, req.recipientId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN,
                "You cannot start a conversation with this user");
        }
        return conversationRepo.findByParticipants(callerUid, req.recipientId())
            .orElseGet(() -> {
                User initiator = userService.getUser(callerUid);
                User recipient = userService.getUser(req.recipientId());

                if (initiator.getRole() == com.tape.api.enums.UserRole.ATHLETE) {
                    throw new ResponseStatusException(HttpStatus.FORBIDDEN,
                        "Athletes cannot initiate conversations");
                }

                Conversation conv = new Conversation();
                conv.setParticipant1(initiator);
                conv.setParticipant2(recipient);
                conv.setInitiatedByRole(initiator.getRole());
                return conversationRepo.save(conv);
            });
    }

    public List<Message> getMessages(String conversationId, String callerUid) {
        Conversation conv = getConversation(conversationId);
        requireParticipant(conv, callerUid);
        return messageRepo.findByConversationIdOrderBySentAtAsc(conversationId);
    }

    /**
     * Marks the other participant's messages in this thread as read.
     *
     * Called when the caller opens the thread. Without this, `isRead` stayed
     * false forever, so the read receipts shown to Pro users never appeared
     * and the inbox unread badge never cleared.
     *
     * @return how many messages changed state
     */
    @Transactional
    public int markRead(String conversationId, String callerUid) {
        Conversation conv = getConversation(conversationId);
        requireParticipant(conv, callerUid);
        return messageRepo.markReadByReader(conversationId, callerUid);
    }

    /**
     * Sends a message from the authenticated caller.
     *
     * The {@code senderId} body field is accepted for backward compatibility
     * with existing iOS clients but the server always uses the token uid as the
     * actual sender identity. Free-tier users are capped at
     * {@value FREE_DM_MONTHLY_CAP} DMs per month enforced here — client-side
     * checks are treated as a UX hint only.
     */
    @Transactional
    public Message sendMessage(String conversationId, SendMessageRequest req, String callerUid) {
        Conversation conv = getConversation(conversationId);
        requireParticipant(conv, callerUid);

        String otherId = conv.otherParticipant(callerUid).getId();
        if (moderationService.isEitherBlocked(callerUid, otherId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN,
                "You cannot message this user");
        }

        User sender = userService.getUser(callerUid);

        // Enforce DM cap server-side for free tier users.
        if (sender.getTier() == SubscriptionTier.FREE
                && sender.getDmsSentThisMonth() >= FREE_DM_MONTHLY_CAP) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN,
                "Monthly DM limit reached. Upgrade to Pro for unlimited messaging.");
        }

        Message msg = new Message();
        msg.setConversation(conv);
        msg.setSender(sender);
        msg.setText(req.text());
        Message saved = messageRepo.save(msg);

        // Increment the monthly counter for free-tier senders server-side.
        if (sender.getTier() == SubscriptionTier.FREE) {
            userService.incrementDmsSent(callerUid);
        }

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

    // ── Internal ──────────────────────────────────────────────────────────────

    private Conversation getConversation(String conversationId) {
        return conversationRepo.findById(conversationId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Conversation not found"));
    }

    private void requireParticipant(Conversation conv, String callerUid) {
        if (!conv.hasParticipant(callerUid)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN,
                "You are not a participant in this conversation");
        }
    }
}
