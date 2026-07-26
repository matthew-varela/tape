package com.tape.api.controller;

import com.tape.api.dto.FollowCountsResponse;
import com.tape.api.dto.FollowRequest;
import com.tape.api.security.SecurityUtils;
import com.tape.api.service.FollowService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import java.util.List;

/**
 * Social graph endpoints. The follower is always the verified Firebase caller,
 * never a body field.
 */
@RestController
@RequestMapping("/api/follows")
public class FollowController {

    private final FollowService followService;

    public FollowController(FollowService followService) {
        this.followService = followService;
    }

    /** POST /api/follows — follow a user. Idempotent. */
    @PostMapping
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void follow(@Valid @RequestBody FollowRequest request) {
        followService.follow(SecurityUtils.requireFirebaseUid(), request.userId());
    }

    /** DELETE /api/follows/{userId} — unfollow a user. Idempotent. */
    @DeleteMapping("/{userId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unfollow(@PathVariable String userId) {
        followService.unfollow(SecurityUtils.requireFirebaseUid(), userId);
    }

    /** GET /api/follows/following — IDs the caller follows. */
    @GetMapping("/following")
    public List<String> following() {
        return followService.getFollowingIds(SecurityUtils.requireFirebaseUid());
    }

    /** GET /api/follows/{userId}/counts — follower/following totals for a profile. */
    @GetMapping("/{userId}/counts")
    public FollowCountsResponse counts(@PathVariable String userId) {
        return followService.getCounts(userId, SecurityUtils.requireFirebaseUid());
    }
}
