package com.tape.api.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "profile_views")
public class ProfileView {

    @Id
    @Column(length = 64)
    private String id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "viewed_user_id", nullable = false)
    private User viewedUser;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "viewer_user_id", nullable = false)
    private User viewer;

    @Column(nullable = false, updatable = false)
    private Instant viewedAt;

    @PrePersist
    private void onCreate() {
        if (id == null) id = UUID.randomUUID().toString();
        if (viewedAt == null) viewedAt = Instant.now();
    }

    public ProfileView() {}

    public String getId() { return id; }
    public void setId(String id) { this.id = id; }

    public User getViewedUser() { return viewedUser; }
    public void setViewedUser(User viewedUser) { this.viewedUser = viewedUser; }

    public User getViewer() { return viewer; }
    public void setViewer(User viewer) { this.viewer = viewer; }

    public Instant getViewedAt() { return viewedAt; }
}
