package com.tape.api.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

/**
 * Records that one user has blocked another. The unique constraint prevents
 * duplicate block rows for the same (blocker, blocked) pair.
 */
@Entity
@Table(name = "blocks",
       uniqueConstraints = @UniqueConstraint(columnNames = {"blocker_id", "blocked_id"}))
public class Block {

    @Id
    @Column(length = 64)
    private String id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "blocker_id", nullable = false)
    private User blocker;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "blocked_id", nullable = false)
    private User blocked;

    @Column(nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    private void onCreate() {
        if (id == null) id = UUID.randomUUID().toString();
        if (createdAt == null) createdAt = Instant.now();
    }

    public Block() {}

    public String getId() { return id; }
    public User getBlocker() { return blocker; }
    public void setBlocker(User blocker) { this.blocker = blocker; }
    public User getBlocked() { return blocked; }
    public void setBlocked(User blocked) { this.blocked = blocked; }
    public Instant getCreatedAt() { return createdAt; }
}
