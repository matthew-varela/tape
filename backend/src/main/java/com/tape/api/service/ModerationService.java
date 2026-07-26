package com.tape.api.service;

import com.tape.api.dto.ReportRequest;
import com.tape.api.entity.Block;
import com.tape.api.entity.Report;
import com.tape.api.entity.User;
import com.tape.api.repository.BlockRepository;
import com.tape.api.repository.ReportRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

/**
 * Handles user-generated-content safety: blocking abusive users and reporting
 * content. Required for App Store compliance for apps with user-generated
 * content (Guideline 1.2).
 */
@Service
public class ModerationService {

    private final BlockRepository blockRepo;
    private final ReportRepository reportRepo;
    private final UserService userService;

    public ModerationService(BlockRepository blockRepo,
                             ReportRepository reportRepo,
                             UserService userService) {
        this.blockRepo = blockRepo;
        this.reportRepo = reportRepo;
        this.userService = userService;
    }

    // ── Blocking ────────────────────────────────────────────────────────────────

    @Transactional
    public void blockUser(String callerUid, String blockedUid) {
        if (callerUid.equals(blockedUid)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "You cannot block yourself");
        }
        // Validates existence (404 if either is missing).
        User blocker = userService.getUser(callerUid);
        User blocked = userService.getUser(blockedUid);

        if (blockRepo.existsByBlockerIdAndBlockedId(callerUid, blockedUid)) {
            return; // Idempotent.
        }
        Block block = new Block();
        block.setBlocker(blocker);
        block.setBlocked(blocked);
        blockRepo.save(block);
    }

    @Transactional
    public void unblockUser(String callerUid, String blockedUid) {
        blockRepo.deleteByBlockerIdAndBlockedId(callerUid, blockedUid);
    }

    /** IDs of users the caller has blocked (shown in the client's block list). */
    public List<String> getBlockedUserIds(String callerUid) {
        return blockRepo.findBlockedIds(callerUid);
    }

    /**
     * IDs to hide from the caller across the app: everyone the caller blocked
     * AND everyone who blocked the caller. Used by feed, search, and messaging.
     */
    public Set<String> getHiddenUserIds(String callerUid) {
        Set<String> hidden = new LinkedHashSet<>(blockRepo.findBlockedIds(callerUid));
        hidden.addAll(blockRepo.findBlockerIds(callerUid));
        return hidden;
    }

    public boolean isEitherBlocked(String userA, String userB) {
        return blockRepo.existsByBlockerIdAndBlockedId(userA, userB)
            || blockRepo.existsByBlockerIdAndBlockedId(userB, userA);
    }

    // ── Reporting ─────────────────────────────────────────────────────────────

    @Transactional
    public Report report(String callerUid, ReportRequest req) {
        User reporter = userService.getUser(callerUid);
        Report report = new Report();
        report.setReporter(reporter);
        report.setTargetType(req.targetType());
        report.setTargetId(req.targetId());
        report.setReason(req.reason());
        report.setDetails(req.details());
        return reportRepo.save(report);
    }
}
