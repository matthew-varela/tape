package com.tape.api.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

/**
 * Directed edge in the social graph: {@code follower} follows {@code followee}.
 * The unique constraint keeps the relationship idempotent so a double-tap on
 * the follow button cannot create two rows.
 */
@Entity
@Table(name = "follows",
       uniqueConstraints = @UniqueConstraint(columnNames = {"follower_id", "followee_id"}))
public class Follow {

    @Id
    @Column(length = 64)
    private String id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "follower_id", nullable = false)
    private User follower;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "followee_id", nullable = false)
    private User followee;

    @Column(nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    private void onCreate() {
        if (id == null) id = UUID.randomUUID().toString();
        if (createdAt == null) createdAt = Instant.now();
    }

    public Follow() {}

    public String getId() { return id; }

    public User getFollower() { return follower; }
    public void setFollower(User follower) { this.follower = follower; }

    public User getFollowee() { return followee; }
    public void setFollowee(User followee) { this.followee = followee; }

    public Instant getCreatedAt() { return createdAt; }
}
