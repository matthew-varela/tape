package com.tape.api.repository;

import com.tape.api.entity.Bookmark;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;
import java.util.Optional;

public interface BookmarkRepository extends JpaRepository<Bookmark, String> {

    List<Bookmark> findByUserIdOrderByCreatedAtDesc(String userId);

    Optional<Bookmark> findByUserIdAndVideoId(String userId, String videoId);

    void deleteByUserIdAndVideoId(String userId, String videoId);

    boolean existsByUserIdAndVideoId(String userId, String videoId);

    /** Deletes all bookmarks created by a user (used for account deletion). */
    @Modifying
    @Query("DELETE FROM Bookmark b WHERE b.user.id = :userId")
    void deleteByUserId(@Param("userId") String userId);

    /**
     * Deletes all bookmarks (by anyone) of videos owned by the given athlete,
     * so the athlete's videos can be removed without violating FK constraints.
     */
    @Modifying
    @Query("DELETE FROM Bookmark b WHERE b.video.id IN (SELECT v.id FROM Video v WHERE v.athlete.id = :athleteId)")
    void deleteByVideoAthleteId(@Param("athleteId") String athleteId);
}
