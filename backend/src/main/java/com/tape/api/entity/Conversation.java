package com.tape.api.entity;

import com.tape.api.enums.UserRole;
import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "conversations")
public class Conversation {

    @Id
    @Column(length = 64)
    private String id;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "participant1_id", nullable = false)
    private User participant1;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "participant2_id", nullable = false)
    private User participant2;

    @Column(length = 1000)
    private String lastMessage;

    private Instant lastMessageDate;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private UserRole initiatedByRole;

    @Column(nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    private void onCreate() {
        if (id == null) id = UUID.randomUUID().toString();
        if (createdAt == null) createdAt = Instant.now();
        if (lastMessageDate == null) lastMessageDate = Instant.now();
    }

    public Conversation() {}

    public String getId() { return id; }
    public void setId(String id) { this.id = id; }

    public User getParticipant1() { return participant1; }
    public void setParticipant1(User participant1) { this.participant1 = participant1; }

    public User getParticipant2() { return participant2; }
    public void setParticipant2(User participant2) { this.participant2 = participant2; }

    public String getLastMessage() { return lastMessage; }
    public void setLastMessage(String lastMessage) { this.lastMessage = lastMessage; }

    public Instant getLastMessageDate() { return lastMessageDate; }
    public void setLastMessageDate(Instant lastMessageDate) { this.lastMessageDate = lastMessageDate; }

    public UserRole getInitiatedByRole() { return initiatedByRole; }
    public void setInitiatedByRole(UserRole initiatedByRole) { this.initiatedByRole = initiatedByRole; }

    public Instant getCreatedAt() { return createdAt; }

    public boolean hasParticipant(String userId) {
        return participant1.getId().equals(userId) || participant2.getId().equals(userId);
    }

    public User otherParticipant(String currentUserId) {
        return participant1.getId().equals(currentUserId) ? participant2 : participant1;
    }
}
