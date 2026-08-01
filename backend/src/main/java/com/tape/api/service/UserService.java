package com.tape.api.service;

import com.tape.api.dto.SignUpRequest;
import com.tape.api.dto.SubscriptionSyncRequest;
import com.tape.api.entity.Bookmark;
import com.tape.api.entity.ProfileView;
import com.tape.api.entity.Subscription;
import com.tape.api.entity.User;
import com.tape.api.entity.Video;
import com.tape.api.enums.SubscriptionTier;
import com.tape.api.enums.UserRole;
import com.tape.api.repository.BlockRepository;
import com.tape.api.repository.BookmarkRepository;
import com.tape.api.repository.ConversationRepository;
import com.tape.api.repository.FollowRepository;
import com.tape.api.repository.MessageRepository;
import com.tape.api.repository.ProfileViewRepository;
import com.tape.api.repository.ReportRepository;
import com.tape.api.repository.SavedAthleteRepository;
import com.tape.api.repository.ScoutingBoardRepository;
import com.tape.api.repository.SubscriptionRepository;
import com.tape.api.repository.UserRepository;
import com.tape.api.repository.VideoRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;

@Service
public class UserService {

    private final UserRepository userRepo;
    private final ProfileViewRepository profileViewRepo;
    private final BookmarkRepository bookmarkRepo;
    private final SubscriptionRepository subscriptionRepo;
    private final VideoRepository videoRepo;
    private final ConversationRepository conversationRepo;
    private final MessageRepository messageRepo;
    private final ScoutingBoardRepository scoutingBoardRepo;
    private final BlockRepository blockRepo;
    private final ReportRepository reportRepo;
    private final FollowRepository followRepo;
    private final SavedAthleteRepository savedAthleteRepo;

    public UserService(UserRepository userRepo,
                       ProfileViewRepository profileViewRepo,
                       BookmarkRepository bookmarkRepo,
                       SubscriptionRepository subscriptionRepo,
                       VideoRepository videoRepo,
                       ConversationRepository conversationRepo,
                       MessageRepository messageRepo,
                       ScoutingBoardRepository scoutingBoardRepo,
                       BlockRepository blockRepo,
                       ReportRepository reportRepo,
                       FollowRepository followRepo,
                       SavedAthleteRepository savedAthleteRepo) {
        this.userRepo = userRepo;
        this.profileViewRepo = profileViewRepo;
        this.bookmarkRepo = bookmarkRepo;
        this.subscriptionRepo = subscriptionRepo;
        this.videoRepo = videoRepo;
        this.conversationRepo = conversationRepo;
        this.messageRepo = messageRepo;
        this.scoutingBoardRepo = scoutingBoardRepo;
        this.blockRepo = blockRepo;
        this.reportRepo = reportRepo;
        this.followRepo = followRepo;
        this.savedAthleteRepo = savedAthleteRepo;
    }

    // ── Account creation ────────────────────────────────────────────────────

    /**
     * Mints a new User record keyed to the verified Firebase UID.
     * The UID is the authoritative identity; it is never derived from the request body.
     */
    /** Minimum age (years) required to create an account (COPPA floor). */
    private static final int MINIMUM_SIGNUP_AGE = 13;

    public User createUser(String uid, SignUpRequest req) {
        if (userRepo.existsById(uid)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "User already exists");
        }
        if (req.dateOfBirth() != null) {
            int age = java.time.Period.between(req.dateOfBirth(), java.time.LocalDate.now()).getYears();
            if (age < MINIMUM_SIGNUP_AGE) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "You must be at least " + MINIMUM_SIGNUP_AGE + " years old to use Tape");
            }
        }
        User user = new User();
        user.setId(uid);
        if (req.email() != null) user.setEmail(req.email());
        user.setDisplayName(req.displayName());
        user.setRole(req.role());
        user.setDateOfBirth(req.dateOfBirth());
        return userRepo.save(user);
    }

    // ── Account deletion ───────────────────────────────────────────────────────

    /**
     * Permanently deletes a user and all data referencing them, in FK-safe
     * order. Required for App Store compliance (Guideline 5.1.1(v)).
     *
     * The deletes are bulk JPQL/native statements run inside a single
     * transaction, so either the whole account is removed or nothing is.
     * Removal of the underlying Firebase Auth user is handled separately by
     * {@link FirebaseAccountService} after this transaction commits.
     */
    @Transactional
    public void deleteAccount(String uid) {
        // 404 if the account does not exist.
        getUser(uid);

        // Join / element-collection tables first (no JPQL cascade to them).
        scoutingBoardRepo.deleteAthleteLinksForUser(uid);
        videoRepo.deleteTagsByAthleteId(uid);

        // Rows that reference the user's videos before the videos themselves.
        bookmarkRepo.deleteByVideoAthleteId(uid);
        bookmarkRepo.deleteByUserId(uid);
        videoRepo.deleteByAthleteId(uid);

        // Messaging: messages before their conversations.
        messageRepo.deleteByParticipant(uid);
        conversationRepo.deleteByParticipant(uid);

        // Moderation: remove block rows involving the user and reports they
        // filed. Reports ABOUT the user are retained for moderation history.
        blockRepo.deleteByUser(uid);
        reportRepo.deleteByReporterId(uid);

        // Social graph edges and shortlists in both directions.
        followRepo.deleteByUser(uid);
        savedAthleteRepo.deleteByUser(uid);

        // Remaining direct references to the user.
        profileViewRepo.deleteByUser(uid);
        scoutingBoardRepo.deleteByOwnerId(uid);
        subscriptionRepo.deleteByUserId(uid);

        userRepo.deleteById(uid);
    }

    // ── Lookup ───────────────────────────────────────────────────────────────

    public User getUser(String id) {
        return userRepo.findById(id)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));
    }

    public User getUserByEmail(String email) {
        return userRepo.findByEmail(email)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));
    }

    public List<User> getUsersByRole(UserRole role) {
        return userRepo.findByRole(role);
    }

    /**
     * General user search; all parameters are optional.
     * Free-text {@code q} matches displayName, school, and sport.
     */
    public List<User> searchUsers(UserRole role, String q, String position, String state, String sport) {
        return userRepo.searchUsers(role, q, position, state, sport);
    }

    public List<User> searchAthletes(String position, String state, String sport, Integer gradYear, Double minGpa) {
        return userRepo.searchAthletes(position, state, sport, gradYear, minGpa);
    }

    // ── Profile update ────────────────────────────────────────────────────────

    /**
     * Applies a partial update to the caller's own profile.
     * Only non-null fields in {@code updates} are applied.
     */
    public User updateUser(String id, User updates) {
        User user = getUser(id);
        if (updates.getDisplayName() != null) user.setDisplayName(updates.getDisplayName());
        if (updates.getProfileImageUrl() != null) user.setProfileImageUrl(updates.getProfileImageUrl());
        if (updates.getHighSchool() != null) user.setHighSchool(updates.getHighSchool());
        if (updates.getGradYear() != null) user.setGradYear(updates.getGradYear());
        if (updates.getSport() != null) user.setSport(updates.getSport());
        if (updates.getPosition() != null) user.setPosition(updates.getPosition());
        if (updates.getState() != null) user.setState(updates.getState());
        if (updates.getHeight() != null) user.setHeight(updates.getHeight());
        if (updates.getWeight() != null) user.setWeight(updates.getWeight());
        if (updates.getFortyYardDash() != null) user.setFortyYardDash(updates.getFortyYardDash());
        if (updates.getGpa() != null) user.setGpa(updates.getGpa());
        if (updates.getOrganization() != null) {
            String organization = updates.getOrganization().isBlank() ? null : updates.getOrganization();
            user.setOrganization(organization);
        }
        if (updates.getTitle() != null) {
            String title = updates.getTitle().isBlank() ? null : updates.getTitle();
            user.setTitle(title);
        }
        // Empty string clears the affiliation (clients send "" when the coach
        // removes their school). Null still means "leave unchanged".
        if (updates.getSchoolId() != null) {
            String schoolId = updates.getSchoolId().isBlank() ? null : updates.getSchoolId();
            user.setSchoolId(schoolId);
        }
        // Empty string clears the handle (clients send "" to remove a link).
        // Null still means "leave unchanged".
        if (updates.getInstagramHandle() != null) {
            user.setInstagramHandle(normalizeSocialHandle(updates.getInstagramHandle()));
        }
        if (updates.getTiktokHandle() != null) {
            user.setTiktokHandle(normalizeSocialHandle(updates.getTiktokHandle()));
        }
        if (updates.getSnapchatHandle() != null) {
            user.setSnapchatHandle(normalizeSocialHandle(updates.getSnapchatHandle()));
        }
        // An empty list is a meaningful value here (clear the shortlist), so
        // only a missing key skips the update.
        if (updates.getTargetSchoolIds() != null) {
            user.getTargetSchoolIds().clear();
            user.getTargetSchoolIds().addAll(updates.getTargetSchoolIds());
        }
        return userRepo.save(user);
    }

    /**
     * Strips whitespace, a leading {@code @}, and common profile URL prefixes
     * so stored values are bare usernames. Blank input clears the field.
     */
    private static String normalizeSocialHandle(String raw) {
        if (raw == null || raw.isBlank()) return null;
        String handle = raw.trim();
        // Accept pasted profile URLs.
        handle = handle.replaceFirst("(?i)^https?://(www\\.)?instagram\\.com/", "");
        handle = handle.replaceFirst("(?i)^https?://(www\\.)?tiktok\\.com/", "");
        handle = handle.replaceFirst("(?i)^https?://(www\\.)?snapchat\\.com/(add/)?", "");
        handle = handle.replaceFirst("^/+", "");
        if (handle.startsWith("@")) handle = handle.substring(1);
        // Drop path/query leftovers from pasted URLs ("user/?hl=en").
        int slash = handle.indexOf('/');
        if (slash >= 0) handle = handle.substring(0, slash);
        int query = handle.indexOf('?');
        if (query >= 0) handle = handle.substring(0, query);
        handle = handle.trim();
        return handle.isEmpty() ? null : handle;
    }

    // ── Profile views ─────────────────────────────────────────────────────────

    public void recordProfileView(String viewedUserId, String viewerUserId) {
        ProfileView pv = new ProfileView();
        pv.setViewedUser(getUser(viewedUserId));
        pv.setViewer(getUser(viewerUserId));
        profileViewRepo.save(pv);
    }

    /**
     * Returns users who viewed the given athlete's profile this week.
     * Requires the caller to have a PRO subscription tier.
     */
    public List<User> getProfileViewers(String targetUserId, String callerUid) {
        User caller = getUser(callerUid);
        if (caller.getTier() != SubscriptionTier.PRO) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN,
                "A Pro subscription is required to see profile viewers");
        }
        Instant oneWeekAgo = Instant.now().minus(7, ChronoUnit.DAYS);
        return profileViewRepo.findRecentViewers(targetUserId, oneWeekAgo)
            .stream()
            .map(ProfileView::getViewer)
            .distinct()
            .toList();
    }

    public long getProfileViewCount(String userId) {
        Instant oneWeekAgo = Instant.now().minus(7, ChronoUnit.DAYS);
        return profileViewRepo.countRecentViewers(userId, oneWeekAgo);
    }

    // ── Bookmarks ─────────────────────────────────────────────────────────────

    /**
     * Returns the video IDs bookmarked by the given user.
     * Caller must own the resource (same uid).
     */
    public List<String> getBookmarkedVideoIds(String userId, String callerUid) {
        requireSelf(userId, callerUid, "view bookmarks");
        return bookmarkRepo.findByUserIdOrderByCreatedAtDesc(userId)
            .stream()
            .map(b -> b.getVideo().getId())
            .toList();
    }

    /** Saved clips as full records, newest save first. Owner-only. */
    public List<Video> getBookmarkedVideos(String userId, String callerUid) {
        requireSelf(userId, callerUid, "view bookmarks");
        return bookmarkRepo.findByUserIdOrderByCreatedAtDesc(userId)
            .stream()
            .map(Bookmark::getVideo)
            .toList();
    }

    /** Adds a bookmark; silently ignores duplicates. */
    @Transactional
    public void addBookmark(String userId, String videoId, String callerUid) {
        requireSelf(userId, callerUid, "add bookmarks");
        if (!bookmarkRepo.existsByUserIdAndVideoId(userId, videoId)) {
            User user = getUser(userId);
            Video video = videoRepo.findById(videoId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Video not found"));
            Bookmark bookmark = new Bookmark();
            bookmark.setUser(user);
            bookmark.setVideo(video);
            bookmarkRepo.save(bookmark);
        }
    }

    /** Removes a bookmark; silently ignores non-existent bookmarks. */
    @Transactional
    public void removeBookmark(String userId, String videoId, String callerUid) {
        requireSelf(userId, callerUid, "remove bookmarks");
        bookmarkRepo.deleteByUserIdAndVideoId(userId, videoId);
    }

    // ── DM quota ──────────────────────────────────────────────────────────────

    /**
     * No-op kept for backward compatibility with iOS clients that call
     * POST /api/users/{id}/dm-sent after sending a message.
     * The DM counter is now incremented server-side in MessageService.sendMessage.
     */
    public void acknowledgeDmSent(String userId, String callerUid) {
        requireSelf(userId, callerUid, "acknowledge DM");
        // Counter is managed server-side; nothing to do here.
    }

    /** Increments the monthly DM counter. Called only from MessageService. */
    public void incrementDmsSent(String userId) {
        User user = getUser(userId);
        user.setDmsSentThisMonth(user.getDmsSentThisMonth() + 1);
        userRepo.save(user);
    }

    // ── Subscription sync ─────────────────────────────────────────────────────

    /**
     * Syncs the subscription state after a StoreKit (iOS) or Play Billing (Android)
     * event. Updates the caller's tier to PRO (active) or FREE (inactive) and
     * persists platform/provider metadata for cross-platform billing history.
     */
    @Transactional
    public void syncSubscription(String callerUid, SubscriptionSyncRequest req) {
        User user = getUser(callerUid);
        user.setTier(req.active() ? SubscriptionTier.PRO : SubscriptionTier.FREE);
        userRepo.save(user);

        Subscription sub = subscriptionRepo.findByUserId(callerUid)
            .orElseGet(() -> {
                Subscription s = new Subscription();
                s.setUser(user);
                return s;
            });
        sub.setPlatform(req.effectivePlatform());
        sub.setProvider(req.effectiveProvider());
        sub.setActive(req.active());
        subscriptionRepo.save(sub);
    }

    // ── Internal helpers ──────────────────────────────────────────────────────

    /**
     * Throws 403 if {@code callerUid} is not the same as {@code resourceOwnerId}.
     * Use for any resource that only the owning user should access.
     */
    private void requireSelf(String resourceOwnerId, String callerUid, String action) {
        if (!resourceOwnerId.equals(callerUid)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN,
                "You are not allowed to " + action + " for another user");
        }
    }
}
