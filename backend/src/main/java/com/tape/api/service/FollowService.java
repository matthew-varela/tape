package com.tape.api.service;

import com.tape.api.dto.FollowCountsResponse;
import com.tape.api.entity.Follow;
import com.tape.api.entity.User;
import com.tape.api.repository.FollowRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import java.util.List;

/**
 * Owns the social graph. Following is one-directional and does not require
 * approval, matching how TikTok and Instagram public accounts behave.
 */
@Service
public class FollowService {

    private final FollowRepository followRepo;
    private final UserService userService;
    private final ModerationService moderationService;

    public FollowService(FollowRepository followRepo,
                         UserService userService,
                         ModerationService moderationService) {
        this.followRepo = followRepo;
        this.userService = userService;
        this.moderationService = moderationService;
    }

    @Transactional
    public void follow(String callerUid, String targetUid) {
        if (callerUid.equals(targetUid)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "You cannot follow yourself");
        }
        // Validates existence (404 if either is missing).
        User follower = userService.getUser(callerUid);
        User followee = userService.getUser(targetUid);

        if (moderationService.isEitherBlocked(callerUid, targetUid)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "You cannot follow this user");
        }
        if (followRepo.existsByFollowerIdAndFolloweeId(callerUid, targetUid)) {
            return; // Idempotent.
        }

        Follow follow = new Follow();
        follow.setFollower(follower);
        follow.setFollowee(followee);
        followRepo.save(follow);
    }

    @Transactional
    public void unfollow(String callerUid, String targetUid) {
        followRepo.deleteByFollowerIdAndFolloweeId(callerUid, targetUid);
    }

    /** IDs the caller follows; the client caches these to render follow state. */
    public List<String> getFollowingIds(String callerUid) {
        return followRepo.findFolloweeIds(callerUid);
    }

    public FollowCountsResponse getCounts(String targetUid, String callerUid) {
        userService.getUser(targetUid);
        return new FollowCountsResponse(
            followRepo.countByFolloweeId(targetUid),
            followRepo.countByFollowerId(targetUid),
            followRepo.existsByFollowerIdAndFolloweeId(callerUid, targetUid)
        );
    }
}
