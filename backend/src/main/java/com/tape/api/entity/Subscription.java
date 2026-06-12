package com.tape.api.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

/**
 * Stores a user's subscription state in a platform-neutral way.
 *
 * {@code platform} is {@code "ios"} or {@code "android"}.
 * {@code provider} is {@code "storekit"} (iOS) or {@code "play_billing"} (Android).
 * This allows the same User record and tier gate to be used regardless of
 * which store processed the purchase.
 */
@Entity
@Table(name = "subscriptions")
public class Subscription {

    @Id
    @Column(length = 64)
    private String id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private User user;

    /** "ios" or "android" */
    private String platform;

    /** "storekit" or "play_billing" */
    private String provider;

    private boolean active;

    @Column(nullable = false)
    private Instant updatedAt;

    @PrePersist
    @PreUpdate
    private void onUpdate() {
        if (id == null) id = UUID.randomUUID().toString();
        updatedAt = Instant.now();
    }

    public Subscription() {}

    public String getId() { return id; }
    public User getUser() { return user; }
    public void setUser(User user) { this.user = user; }
    public String getPlatform() { return platform; }
    public void setPlatform(String platform) { this.platform = platform; }
    public String getProvider() { return provider; }
    public void setProvider(String provider) { this.provider = provider; }
    public boolean isActive() { return active; }
    public void setActive(boolean active) { this.active = active; }
    public Instant getUpdatedAt() { return updatedAt; }
}
