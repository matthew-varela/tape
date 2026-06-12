package com.tape.api;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.tape.api.entity.User;
import com.tape.api.enums.SubscriptionTier;
import com.tape.api.enums.UserRole;
import com.tape.api.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.jdbc.Sql;
import org.springframework.test.web.servlet.MockMvc;

import java.util.Map;

import static org.hamcrest.Matchers.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * Contract and authorization tests.
 *
 * Firebase is disabled in the "local" profile; authentication is simulated by
 * sending the {@code X-Test-User-ID} header, which FirebaseAuthenticationFilter
 * converts into an authenticated principal when Firebase is off.
 *
 * Each test validates:
 *  - The HTTP status code matches the contract.
 *  - The response body always uses the {@code { "message": "..." }} error shape.
 *  - Authorization rules prevent one user from accessing another user's data.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("local")
@Sql(scripts = "/test-reset.sql", executionPhase = Sql.ExecutionPhase.BEFORE_TEST_METHOD)
class TapeApiApplicationTests {

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper mapper;
    @Autowired UserRepository userRepo;

    private static final String UID_ATHLETE   = "test-athlete-uid";
    private static final String UID_RECRUITER = "test-recruiter-uid";
    private static final String UID_FREE_REC  = "test-free-recruiter-uid";

    // @Sql above truncates all tables before each test; this method re-seeds base users.
    @BeforeEach
    void seed() {
        userRepo.save(athlete(UID_ATHLETE, SubscriptionTier.PRO));
        userRepo.save(recruiter(UID_RECRUITER, SubscriptionTier.PRO));
        userRepo.save(recruiter(UID_FREE_REC, SubscriptionTier.FREE));
    }

    // ── Health ────────────────────────────────────────────────────────────────

    @Test
    void health_isPublic() throws Exception {
        mvc.perform(get("/api/health"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.status").value("UP"));
    }

    // ── Auth ──────────────────────────────────────────────────────────────────

    @Test
    void signup_createsUser() throws Exception {
        mvc.perform(post("/api/auth/signup")
                .header("X-Test-User-ID", "brand-new-uid")
                .contentType(MediaType.APPLICATION_JSON)
                .content(mapper.writeValueAsString(Map.of(
                    "displayName", "New User",
                    "email", "new@test.com",
                    "role", "ATHLETE"
                ))))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.id").value("brand-new-uid"))
            .andExpect(jsonPath("$.role").value("ATHLETE"));
    }

    @Test
    void signup_409_ifAlreadyExists() throws Exception {
        mvc.perform(post("/api/auth/signup")
                .header("X-Test-User-ID", UID_ATHLETE)
                .contentType(MediaType.APPLICATION_JSON)
                .content(mapper.writeValueAsString(Map.of("displayName", "Dup", "role", "ATHLETE"))))
            .andExpect(status().isConflict())
            .andExpect(jsonPath("$.message").exists());
    }

    @Test
    void signin_returnsUser() throws Exception {
        mvc.perform(post("/api/auth/signin")
                .header("X-Test-User-ID", UID_ATHLETE)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{}"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.id").value(UID_ATHLETE));
    }

    @Test
    void signin_404_ifNotRegistered() throws Exception {
        mvc.perform(post("/api/auth/signin")
                .header("X-Test-User-ID", "ghost-uid")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{}"))
            .andExpect(status().isNotFound())
            .andExpect(jsonPath("$.message").exists());
    }

    // ── Users / me ────────────────────────────────────────────────────────────

    @Test
    void getMe_returnsCallerProfile() throws Exception {
        mvc.perform(get("/api/users/me")
                .header("X-Test-User-ID", UID_ATHLETE))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.id").value(UID_ATHLETE));
    }

    @Test
    void getMe_401_withoutAuth() throws Exception {
        mvc.perform(get("/api/users/me"))
            .andExpect(status().isUnauthorized())
            .andExpect(jsonPath("$.message").exists());
    }

    // ── Profile update authorization ──────────────────────────────────────────

    @Test
    void updateUser_403_ifNotOwn() throws Exception {
        mvc.perform(put("/api/users/" + UID_ATHLETE)
                .header("X-Test-User-ID", UID_RECRUITER)
                .contentType(MediaType.APPLICATION_JSON)
                .content(mapper.writeValueAsString(Map.of("displayName", "Hacked"))))
            .andExpect(status().isForbidden())
            .andExpect(jsonPath("$.message").exists());
    }

    @Test
    void updateUser_200_ifOwn() throws Exception {
        mvc.perform(put("/api/users/" + UID_ATHLETE)
                .header("X-Test-User-ID", UID_ATHLETE)
                .contentType(MediaType.APPLICATION_JSON)
                .content(mapper.writeValueAsString(Map.of("displayName", "Updated"))))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.displayName").value("Updated"));
    }

    // ── Profile viewers Pro gate ──────────────────────────────────────────────

    @Test
    void viewers_403_forFreeUser() throws Exception {
        mvc.perform(get("/api/users/" + UID_ATHLETE + "/viewers")
                .header("X-Test-User-ID", UID_FREE_REC))
            .andExpect(status().isForbidden())
            .andExpect(jsonPath("$.message").exists());
    }

    @Test
    void viewers_200_forProUser() throws Exception {
        mvc.perform(get("/api/users/" + UID_ATHLETE + "/viewers")
                .header("X-Test-User-ID", UID_RECRUITER))
            .andExpect(status().isOk());
    }

    // ── Bookmarks authorization ───────────────────────────────────────────────

    @Test
    void getBookmarks_403_forOtherUser() throws Exception {
        mvc.perform(get("/api/users/" + UID_ATHLETE + "/bookmarks")
                .header("X-Test-User-ID", UID_RECRUITER))
            .andExpect(status().isForbidden())
            .andExpect(jsonPath("$.message").exists());
    }

    @Test
    void getBookmarks_200_forOwner() throws Exception {
        mvc.perform(get("/api/users/" + UID_ATHLETE + "/bookmarks")
                .header("X-Test-User-ID", UID_ATHLETE))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.videoIds").isArray());
    }

    // ── DM counter ────────────────────────────────────────────────────────────

    @Test
    void dmSent_204_forOwner() throws Exception {
        mvc.perform(post("/api/users/" + UID_RECRUITER + "/dm-sent")
                .header("X-Test-User-ID", UID_RECRUITER))
            .andExpect(status().isNoContent());
    }

    @Test
    void dmSent_403_forOtherUser() throws Exception {
        mvc.perform(post("/api/users/" + UID_ATHLETE + "/dm-sent")
                .header("X-Test-User-ID", UID_RECRUITER))
            .andExpect(status().isForbidden())
            .andExpect(jsonPath("$.message").exists());
    }

    // ── Subscription sync ─────────────────────────────────────────────────────

    @Test
    void subscriptionSync_upgradesAndDowngrades() throws Exception {
        mvc.perform(post("/api/users/me/subscription")
                .header("X-Test-User-ID", UID_FREE_REC)
                .contentType(MediaType.APPLICATION_JSON)
                .content(mapper.writeValueAsString(Map.of("active", true))))
            .andExpect(status().isNoContent());

        mvc.perform(get("/api/users/me")
                .header("X-Test-User-ID", UID_FREE_REC))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.tier").value("PRO"));

        mvc.perform(post("/api/users/me/subscription")
                .header("X-Test-User-ID", UID_FREE_REC)
                .contentType(MediaType.APPLICATION_JSON)
                .content(mapper.writeValueAsString(Map.of("active", false))))
            .andExpect(status().isNoContent());

        mvc.perform(get("/api/users/me")
                .header("X-Test-User-ID", UID_FREE_REC))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.tier").value("FREE"));
    }

    // ── User search ───────────────────────────────────────────────────────────

    @Test
    void searchUsers_returnsResults() throws Exception {
        mvc.perform(get("/api/users/search")
                .header("X-Test-User-ID", UID_RECRUITER)
                .param("role", "ATHLETE"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$", hasSize(greaterThanOrEqualTo(1))));
    }

    // ── Error shape ───────────────────────────────────────────────────────────

    @Test
    void notFound_hasMessageField() throws Exception {
        mvc.perform(get("/api/users/does-not-exist")
                .header("X-Test-User-ID", UID_ATHLETE))
            .andExpect(status().isNotFound())
            .andExpect(jsonPath("$.message").exists());
    }

    @Test
    void unauthenticated_hasMessageField() throws Exception {
        mvc.perform(get("/api/users/me"))
            .andExpect(status().isUnauthorized())
            .andExpect(jsonPath("$.message").exists());
    }

    // ── Conversation DM cap ───────────────────────────────────────────────────

    @Test
    void sendMessage_403_whenFreeTierCapReached() throws Exception {
        // Exhaust the free-tier DM cap by setting counter directly.
        User freeUser = userRepo.findById(UID_FREE_REC).orElseThrow();
        freeUser.setDmsSentThisMonth(10);
        userRepo.save(freeUser);

        // Start a conversation first.
        String convJson = mvc.perform(post("/api/conversations")
                .header("X-Test-User-ID", UID_FREE_REC)
                .contentType(MediaType.APPLICATION_JSON)
                .content(mapper.writeValueAsString(Map.of("recipientId", UID_ATHLETE))))
            .andExpect(status().isCreated())
            .andReturn().getResponse().getContentAsString();

        String convId = mapper.readTree(convJson).get("id").asText();

        mvc.perform(post("/api/conversations/" + convId + "/messages")
                .header("X-Test-User-ID", UID_FREE_REC)
                .contentType(MediaType.APPLICATION_JSON)
                .content(mapper.writeValueAsString(Map.of("text", "Should be blocked"))))
            .andExpect(status().isForbidden())
            .andExpect(jsonPath("$.message").exists());
    }

    // ── Scouting boards ───────────────────────────────────────────────────────

    @Test
    void scoutingBoard_createAndRenameAndDelete() throws Exception {
        // Create
        String boardJson = mvc.perform(post("/api/scouting-boards")
                .header("X-Test-User-ID", UID_RECRUITER)
                .contentType(MediaType.APPLICATION_JSON)
                .content(mapper.writeValueAsString(Map.of("name", "Test Board"))))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.name").value("Test Board"))
            .andReturn().getResponse().getContentAsString();

        String boardId = mapper.readTree(boardJson).get("id").asText();

        // Rename
        mvc.perform(patch("/api/scouting-boards/" + boardId)
                .header("X-Test-User-ID", UID_RECRUITER)
                .contentType(MediaType.APPLICATION_JSON)
                .content(mapper.writeValueAsString(Map.of("name", "Renamed Board"))))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.name").value("Renamed Board"));

        // Other user cannot rename
        mvc.perform(patch("/api/scouting-boards/" + boardId)
                .header("X-Test-User-ID", UID_ATHLETE)
                .contentType(MediaType.APPLICATION_JSON)
                .content(mapper.writeValueAsString(Map.of("name", "Stolen"))))
            .andExpect(status().isForbidden())
            .andExpect(jsonPath("$.message").exists());

        // Add athlete
        mvc.perform(post("/api/scouting-boards/" + boardId + "/athletes")
                .header("X-Test-User-ID", UID_RECRUITER)
                .contentType(MediaType.APPLICATION_JSON)
                .content(mapper.writeValueAsString(Map.of("athleteId", UID_ATHLETE))))
            .andExpect(status().isOk());

        // Delete
        mvc.perform(delete("/api/scouting-boards/" + boardId)
                .header("X-Test-User-ID", UID_RECRUITER))
            .andExpect(status().isNoContent());

        // Board is gone
        mvc.perform(patch("/api/scouting-boards/" + boardId)
                .header("X-Test-User-ID", UID_RECRUITER)
                .contentType(MediaType.APPLICATION_JSON)
                .content(mapper.writeValueAsString(Map.of("name", "Ghost"))))
            .andExpect(status().isNotFound());
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private User athlete(String uid, SubscriptionTier tier) {
        User u = new User();
        u.setId(uid);
        u.setEmail(uid + "@test.com");
        u.setDisplayName("Athlete " + uid);
        u.setRole(UserRole.ATHLETE);
        u.setTier(tier);
        return u;
    }

    private User recruiter(String uid, SubscriptionTier tier) {
        User u = new User();
        u.setId(uid);
        u.setEmail(uid + "@test.com");
        u.setDisplayName("Recruiter " + uid);
        u.setRole(UserRole.RECRUITER);
        u.setTier(tier);
        return u;
    }
}
