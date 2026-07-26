package com.tape.api.controller;

import com.tape.api.dto.BookmarkResponse;
import com.tape.api.dto.SubscriptionSyncRequest;
import com.tape.api.entity.User;
import com.tape.api.enums.UserRole;
import com.tape.api.security.SecurityUtils;
import com.tape.api.service.FirebaseAccountService;
import com.tape.api.service.UserService;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import java.util.List;
import java.util.Map;

/**
 * User profile, search, bookmarks, DM counter, and subscription endpoints.
 *
 * All mutating operations enforce caller identity via the verified Firebase
 * Bearer token. The {@code /me} routes always operate on the authenticated
 * caller; the {@code /{id}} routes require the id to match the caller uid
 * wherever the resource is private.
 */
@RestController
@RequestMapping("/api/users")
public class UserController {

    private final UserService userService;
    private final FirebaseAccountService firebaseAccountService;

    public UserController(UserService userService, FirebaseAccountService firebaseAccountService) {
        this.userService = userService;
        this.firebaseAccountService = firebaseAccountService;
    }

    // ── Session hydration ─────────────────────────────────────────────────────

    @GetMapping("/me")
    public User getCurrentUser() {
        return userService.getUser(SecurityUtils.requireFirebaseUid());
    }

    /**
     * DELETE /api/users/me — permanently deletes the caller's account and all
     * associated data, plus their Firebase Auth user. Required for App Store
     * compliance (Guideline 5.1.1(v)).
     */
    @DeleteMapping("/me")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteCurrentUser() {
        String uid = SecurityUtils.requireFirebaseUid();
        userService.deleteAccount(uid);
        firebaseAccountService.deleteUser(uid);
    }

    // ── Profile lookup ────────────────────────────────────────────────────────

    @GetMapping("/{id}")
    public User getUser(@PathVariable String id) {
        return userService.getUser(id);
    }

    @GetMapping
    public List<User> getUsersByRole(@RequestParam UserRole role) {
        return userService.getUsersByRole(role);
    }

    /**
     * GET /api/users/search
     * All params are optional; q matches displayName, school, and sport.
     */
    @GetMapping("/search")
    public List<User> searchUsers(
            @RequestParam(required = false) String q,
            @RequestParam(required = false) UserRole role,
            @RequestParam(required = false) String position,
            @RequestParam(required = false) String state,
            @RequestParam(required = false) String sport) {
        return userService.searchUsers(role, q, position, state, sport);
    }

    // ── Profile update ────────────────────────────────────────────────────────

    /**
     * PUT /api/users/{id} — only the authenticated user may update their own profile.
     */
    @PutMapping("/{id}")
    public User updateUser(@PathVariable String id, @RequestBody User updates) {
        String uid = SecurityUtils.requireFirebaseUid();
        if (!id.equals(uid)) {
            throw new org.springframework.web.server.ResponseStatusException(
                org.springframework.http.HttpStatus.FORBIDDEN,
                "You may only update your own profile");
        }
        return userService.updateUser(id, updates);
    }

    // ── Profile views ─────────────────────────────────────────────────────────

    @GetMapping("/{id}/viewers")
    public List<User> getProfileViewers(@PathVariable String id) {
        String uid = SecurityUtils.requireFirebaseUid();
        return userService.getProfileViewers(id, uid);
    }

    @GetMapping("/{id}/view-count")
    public Map<String, Long> getProfileViewCount(@PathVariable String id) {
        return Map.of("count", userService.getProfileViewCount(id));
    }

    @PostMapping("/{id}/views")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void recordProfileView(@PathVariable String id) {
        String viewerUid = SecurityUtils.requireFirebaseUid();
        userService.recordProfileView(id, viewerUid);
    }

    // ── Bookmarks ─────────────────────────────────────────────────────────────

    @GetMapping("/{id}/bookmarks")
    public BookmarkResponse getBookmarks(@PathVariable String id) {
        String uid = SecurityUtils.requireFirebaseUid();
        List<String> videoIds = userService.getBookmarkedVideoIds(id, uid);
        return new BookmarkResponse(videoIds);
    }

    @PostMapping("/{id}/bookmarks")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void addBookmark(@PathVariable String id, @RequestBody Map<String, String> body) {
        String uid = SecurityUtils.requireFirebaseUid();
        userService.addBookmark(id, body.get("videoId"), uid);
    }

    @DeleteMapping("/{id}/bookmarks/{videoId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void removeBookmark(@PathVariable String id, @PathVariable String videoId) {
        String uid = SecurityUtils.requireFirebaseUid();
        userService.removeBookmark(id, videoId, uid);
    }

    // ── DM counter ────────────────────────────────────────────────────────────

    /**
     * Legacy backward-compat endpoint. The DM counter is now enforced in
     * MessageService.sendMessage; this is a no-op returning 204.
     */
    @PostMapping("/{id}/dm-sent")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void dmSent(@PathVariable String id) {
        String uid = SecurityUtils.requireFirebaseUid();
        userService.acknowledgeDmSent(id, uid);
    }

    // ── Subscription sync ─────────────────────────────────────────────────────

    @PostMapping("/me/subscription")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void syncSubscription(@RequestBody SubscriptionSyncRequest request) {
        String uid = SecurityUtils.requireFirebaseUid();
        userService.syncSubscription(uid, request);
    }
}
