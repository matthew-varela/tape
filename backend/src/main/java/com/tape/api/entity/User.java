package com.tape.api.entity;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.tape.api.enums.SubscriptionTier;
import com.tape.api.enums.UserRole;
import jakarta.persistence.*;
import java.time.Instant;
import java.time.LocalDate;
import java.time.Period;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Hibernate lazy-proxy properties are excluded from serialization so Jackson
 * does not fail when this entity is the lazy side of a @ManyToOne relationship.
 */
@JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
@Entity
@Table(name = "users")
public class User {

    @Id
    @Column(length = 64)
    private String id;

    @Column(unique = true)
    private String email;

    @Column(nullable = false)
    private String displayName;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private UserRole role;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 8)
    private SubscriptionTier tier = SubscriptionTier.FREE;

    /** Used for age gating and minor-safety handling. Nullable for pre-existing accounts. */
    private LocalDate dateOfBirth;

    private String profileImageUrl;

    // Athlete fields
    private String highSchool;
    private Integer gradYear;
    private String sport;
    private String position;
    private String state;
    private String height;
    private String weight;
    private String fortyYardDash;
    private Double gpa;

    /**
     * Ranked shortlist of programs an athlete wants to play for. Values are
     * ids from the static school catalog shipped with the clients.
     */
    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "athlete_target_schools", joinColumns = @JoinColumn(name = "user_id"))
    @OrderColumn(name = "sort_order")
    @Column(name = "school_id", length = 16)
    private List<String> targetSchoolIds = new ArrayList<>();

    // Recruiter / Brand fields
    private String organization;
    private String title;

    /** Catalog id of the program a recruiter coaches for. */
    @Column(length = 16)
    private String schoolId;

    /** Instagram username without leading @. Null/blank hides the profile icon. */
    @Column(length = 64)
    private String instagramHandle;

    /** TikTok username without leading @. Null/blank hides the profile icon. */
    @Column(length = 64)
    private String tiktokHandle;

    private int dmsSentThisMonth;

    @Column(nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    private void onCreate() {
        if (id == null) id = UUID.randomUUID().toString();
        if (createdAt == null) createdAt = Instant.now();
    }

    public User() {}

    // Getters and setters

    public String getId() { return id; }
    public void setId(String id) { this.id = id; }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public String getDisplayName() { return displayName; }
    public void setDisplayName(String displayName) { this.displayName = displayName; }

    public UserRole getRole() { return role; }
    public void setRole(UserRole role) { this.role = role; }

    public SubscriptionTier getTier() { return tier; }
    public void setTier(SubscriptionTier tier) { this.tier = tier; }

    public LocalDate getDateOfBirth() { return dateOfBirth; }
    public void setDateOfBirth(LocalDate dateOfBirth) { this.dateOfBirth = dateOfBirth; }

    /**
     * Serialized to clients as {@code "minor": true|false}. A user with an
     * unknown date of birth is treated as not-a-minor (false) so legacy
     * accounts don't get incorrectly flagged; new signups always provide it.
     */
    @Transient
    @JsonProperty("minor")
    public boolean isMinor() {
        if (dateOfBirth == null) return false;
        return Period.between(dateOfBirth, LocalDate.now()).getYears() < 18;
    }

    public String getProfileImageUrl() { return profileImageUrl; }
    public void setProfileImageUrl(String profileImageUrl) { this.profileImageUrl = profileImageUrl; }

    public String getHighSchool() { return highSchool; }
    public void setHighSchool(String highSchool) { this.highSchool = highSchool; }

    public Integer getGradYear() { return gradYear; }
    public void setGradYear(Integer gradYear) { this.gradYear = gradYear; }

    public String getSport() { return sport; }
    public void setSport(String sport) { this.sport = sport; }

    public String getPosition() { return position; }
    public void setPosition(String position) { this.position = position; }

    public String getState() { return state; }
    public void setState(String state) { this.state = state; }

    public String getHeight() { return height; }
    public void setHeight(String height) { this.height = height; }

    public String getWeight() { return weight; }
    public void setWeight(String weight) { this.weight = weight; }

    public String getFortyYardDash() { return fortyYardDash; }
    public void setFortyYardDash(String fortyYardDash) { this.fortyYardDash = fortyYardDash; }

    public Double getGpa() { return gpa; }
    public void setGpa(Double gpa) { this.gpa = gpa; }

    public String getOrganization() { return organization; }
    public void setOrganization(String organization) { this.organization = organization; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public List<String> getTargetSchoolIds() { return targetSchoolIds; }
    public void setTargetSchoolIds(List<String> targetSchoolIds) { this.targetSchoolIds = targetSchoolIds; }

    public String getSchoolId() { return schoolId; }
    public void setSchoolId(String schoolId) { this.schoolId = schoolId; }

    public String getInstagramHandle() { return instagramHandle; }
    public void setInstagramHandle(String instagramHandle) { this.instagramHandle = instagramHandle; }

    public String getTiktokHandle() { return tiktokHandle; }
    public void setTiktokHandle(String tiktokHandle) { this.tiktokHandle = tiktokHandle; }

    public int getDmsSentThisMonth() { return dmsSentThisMonth; }
    public void setDmsSentThisMonth(int dmsSentThisMonth) { this.dmsSentThisMonth = dmsSentThisMonth; }

    public Instant getCreatedAt() { return createdAt; }
}
