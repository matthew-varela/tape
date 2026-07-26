package com.tape.api.repository;

import com.tape.api.entity.ScoutingBoard;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;
import java.util.Optional;

public interface ScoutingBoardRepository extends JpaRepository<ScoutingBoard, String> {

    /**
     * Loads boards with {@code owner} via {@code JOIN FETCH} so JSON serialization works with
     * {@code spring.jpa.open-in-view=false}. (Entity graphs on custom {@code @Query} are not always applied.)
     */
    @Query("SELECT b FROM ScoutingBoard b JOIN FETCH b.owner WHERE b.owner.id = :ownerId ORDER BY b.createdAt DESC")
    List<ScoutingBoard> findByOwnerIdOrderByCreatedAtDesc(@Param("ownerId") String ownerId);

    /** Single-board fetch with owner eagerly loaded via join fetch. */
    @Query("SELECT b FROM ScoutingBoard b JOIN FETCH b.owner WHERE b.id = :id")
    Optional<ScoutingBoard> findByIdWithOwner(@Param("id") String id);

    /**
     * Removes a user's links in the @ManyToMany join table — both boards they
     * own and boards (owned by anyone) on which they appear as an athlete.
     * JPQL cannot target the join table directly, so this uses native SQL and
     * must run before {@link #deleteByOwnerId(String)} during account deletion.
     */
    @Modifying
    @Query(value = "DELETE FROM scouting_board_athletes WHERE athlete_id = :userId " +
                   "OR board_id IN (SELECT id FROM scouting_boards WHERE owner_id = :userId)",
           nativeQuery = true)
    void deleteAthleteLinksForUser(@Param("userId") String userId);

    /** Deletes all boards owned by a user (used for account deletion). */
    @Modifying
    @Query("DELETE FROM ScoutingBoard b WHERE b.owner.id = :userId")
    void deleteByOwnerId(@Param("userId") String userId);
}
