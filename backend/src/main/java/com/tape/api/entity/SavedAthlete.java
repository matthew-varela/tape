package com.tape.api.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

/**
 * A recruiter or brand saving an athlete for later. Deliberately simpler than
 * {@link ScoutingBoard}: no naming, no organisation, just a flat shortlist —
 * the athlete-profile equivalent of bookmarking a video.
 */
@Entity
@Table(name = "saved_athletes",
       uniqueConstraints = @UniqueConstraint(columnNames = {"scout_id", "athlete_id"}))
public class SavedAthlete {

    @Id
    @Column(length = 64)
    private String id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "scout_id", nullable = false)
    private User scout;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "athlete_id", nullable = false)
    private User athlete;

    @Column(nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    private void onCreate() {
        if (id == null) id = UUID.randomUUID().toString();
        if (createdAt == null) createdAt = Instant.now();
    }

    public SavedAthlete() {}

    public String getId() { return id; }

    public User getScout() { return scout; }
    public void setScout(User scout) { this.scout = scout; }

    public User getAthlete() { return athlete; }
    public void setAthlete(User athlete) { this.athlete = athlete; }

    public Instant getCreatedAt() { return createdAt; }
}
