package com.tape.api.controller;

import com.tape.api.dto.BlockRequest;
import com.tape.api.dto.ReportRequest;
import com.tape.api.security.SecurityUtils;
import com.tape.api.service.ModerationService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import java.util.List;

/**
 * User-generated-content safety endpoints: reporting content and blocking
 * users. The acting user is always the verified Firebase caller.
 */
@RestController
@RequestMapping("/api")
public class ModerationController {

    private final ModerationService moderationService;

    public ModerationController(ModerationService moderationService) {
        this.moderationService = moderationService;
    }

    /** POST /api/reports — report a video, user, or message. */
    @PostMapping("/reports")
    @ResponseStatus(HttpStatus.CREATED)
    public void report(@Valid @RequestBody ReportRequest request) {
        String uid = SecurityUtils.requireFirebaseUid();
        moderationService.report(uid, request);
    }

    /** GET /api/blocks — IDs of users the caller has blocked. */
    @GetMapping("/blocks")
    public List<String> getBlocks() {
        String uid = SecurityUtils.requireFirebaseUid();
        return moderationService.getBlockedUserIds(uid);
    }

    /** POST /api/blocks — block a user. Idempotent. */
    @PostMapping("/blocks")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void block(@Valid @RequestBody BlockRequest request) {
        String uid = SecurityUtils.requireFirebaseUid();
        moderationService.blockUser(uid, request.userId());
    }

    /** DELETE /api/blocks/{userId} — unblock a user. Idempotent. */
    @DeleteMapping("/blocks/{userId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unblock(@PathVariable String userId) {
        String uid = SecurityUtils.requireFirebaseUid();
        moderationService.unblockUser(uid, userId);
    }
}
