package com.tape.api.service;

import com.tape.api.entity.SavedAthlete;
import com.tape.api.entity.User;
import com.tape.api.enums.UserRole;
import com.tape.api.repository.SavedAthleteRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import java.util.List;

/**
 * Flat "save this player" shortlist for recruiters and brands. Scouting boards
 * remain the tool for organising athletes into named groups; this is the
 * one-tap equivalent of a video bookmark.
 */
@Service
public class SavedAthleteService {

    private final SavedAthleteRepository savedRepo;
    private final UserService userService;
    private final ModerationService moderationService;

    public SavedAthleteService(SavedAthleteRepository savedRepo,
                               UserService userService,
                               ModerationService moderationService) {
        this.savedRepo = savedRepo;
        this.userService = userService;
        this.moderationService = moderationService;
    }

    @Transactional
    public void save(String callerUid, String athleteId) {
        User scout = userService.getUser(callerUid);
        if (scout.getRole() == UserRole.ATHLETE) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN,
                "Only recruiters and brands can save players");
        }
        User athlete = userService.getUser(athleteId);
        if (athlete.getRole() != UserRole.ATHLETE) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "That user is not an athlete");
        }
        if (moderationService.isEitherBlocked(callerUid, athleteId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "You cannot save this player");
        }
        if (savedRepo.existsByScoutIdAndAthleteId(callerUid, athleteId)) {
            return; // Idempotent.
        }

        SavedAthlete saved = new SavedAthlete();
        saved.setScout(scout);
        saved.setAthlete(athlete);
        savedRepo.save(saved);
    }

    @Transactional
    public void unsave(String callerUid, String athleteId) {
        savedRepo.deleteByScoutIdAndAthleteId(callerUid, athleteId);
    }

    /** Full athlete records, newest save first, for the caller's shortlist. */
    public List<User> getSavedAthletes(String callerUid) {
        return savedRepo.findByScoutIdOrderByCreatedAtDesc(callerUid).stream()
            .map(SavedAthlete::getAthlete)
            .toList();
    }
}
