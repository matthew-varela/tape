package com.tape.api.repository;

import com.tape.api.entity.SavedAthlete;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;

public interface SavedAthleteRepository extends JpaRepository<SavedAthlete, String> {

    boolean existsByScoutIdAndAthleteId(String scoutId, String athleteId);

    void deleteByScoutIdAndAthleteId(String scoutId, String athleteId);

    List<SavedAthlete> findByScoutIdOrderByCreatedAtDesc(String scoutId);

    /** Removes every row touching the user (used for account deletion). */
    @Modifying
    @Query("DELETE FROM SavedAthlete s WHERE s.scout.id = :userId OR s.athlete.id = :userId")
    void deleteByUser(@Param("userId") String userId);
}
