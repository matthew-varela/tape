package com.tape.api.service;

import com.tape.api.dto.SignUpRequest;
import com.tape.api.entity.ProfileView;
import com.tape.api.entity.User;
import com.tape.api.enums.UserRole;
import com.tape.api.repository.ProfileViewRepository;
import com.tape.api.repository.UserRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;

@Service
public class UserService {

    private final UserRepository userRepo;
    private final ProfileViewRepository profileViewRepo;

    public UserService(UserRepository userRepo, ProfileViewRepository profileViewRepo) {
        this.userRepo = userRepo;
        this.profileViewRepo = profileViewRepo;
    }

    public User createUser(SignUpRequest req) {
        if (userRepo.findByEmail(req.email()).isPresent()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Email already registered");
        }
        User user = new User();
        if (req.firebaseUid() != null) {
            user.setId(req.firebaseUid());
        }
        user.setEmail(req.email());
        user.setDisplayName(req.displayName());
        user.setRole(req.role());
        return userRepo.save(user);
    }

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

    public List<User> searchAthletes(String position, String state, String sport, Integer gradYear, Double minGpa) {
        return userRepo.searchAthletes(position, state, sport, gradYear, minGpa);
    }

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
        if (updates.getOrganization() != null) user.setOrganization(updates.getOrganization());
        if (updates.getTitle() != null) user.setTitle(updates.getTitle());
        return userRepo.save(user);
    }

    public void recordProfileView(String viewedUserId, String viewerUserId) {
        ProfileView pv = new ProfileView();
        pv.setViewedUser(getUser(viewedUserId));
        pv.setViewer(getUser(viewerUserId));
        profileViewRepo.save(pv);
    }

    public List<User> getProfileViewers(String userId) {
        Instant oneWeekAgo = Instant.now().minus(7, ChronoUnit.DAYS);
        return profileViewRepo.findRecentViewers(userId, oneWeekAgo)
            .stream()
            .map(ProfileView::getViewer)
            .distinct()
            .toList();
    }

    public long getProfileViewCount(String userId) {
        Instant oneWeekAgo = Instant.now().minus(7, ChronoUnit.DAYS);
        return profileViewRepo.countRecentViewers(userId, oneWeekAgo);
    }
}
