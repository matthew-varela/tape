package com.tape.api.controller;

import com.tape.api.dto.SavedAthleteRequest;
import com.tape.api.entity.User;
import com.tape.api.security.SecurityUtils;
import com.tape.api.service.SavedAthleteService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import java.util.List;

/**
 * Recruiter/brand shortlist of athletes. The scout is always the verified
 * Firebase caller.
 */
@RestController
@RequestMapping("/api/saved-athletes")
public class SavedAthleteController {

    private final SavedAthleteService savedAthleteService;

    public SavedAthleteController(SavedAthleteService savedAthleteService) {
        this.savedAthleteService = savedAthleteService;
    }

    /** GET /api/saved-athletes — the caller's shortlist, newest first. */
    @GetMapping
    public List<User> getSaved() {
        return savedAthleteService.getSavedAthletes(SecurityUtils.requireFirebaseUid());
    }

    /** POST /api/saved-athletes — save a player. Idempotent. */
    @PostMapping
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void save(@Valid @RequestBody SavedAthleteRequest request) {
        savedAthleteService.save(SecurityUtils.requireFirebaseUid(), request.athleteId());
    }

    /** DELETE /api/saved-athletes/{athleteId} — unsave. Idempotent. */
    @DeleteMapping("/{athleteId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unsave(@PathVariable String athleteId) {
        savedAthleteService.unsave(SecurityUtils.requireFirebaseUid(), athleteId);
    }
}
