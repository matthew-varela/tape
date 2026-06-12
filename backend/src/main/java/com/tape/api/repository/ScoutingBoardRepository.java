package com.tape.api.repository;

import com.tape.api.entity.ScoutingBoard;
import org.springframework.data.jpa.repository.JpaRepository;
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
}
