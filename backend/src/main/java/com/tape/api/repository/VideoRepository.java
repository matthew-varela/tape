package com.tape.api.repository;

import com.tape.api.entity.Video;
import com.tape.api.enums.VideoCategory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;

public interface VideoRepository extends JpaRepository<Video, String> {

    Page<Video> findAllByOrderByCreatedAtDesc(Pageable pageable);

    /** Pinned videos first, then newest — matches iOS ProfileViewModel sort order. */
    @Query("SELECT v FROM Video v WHERE v.athlete.id = :athleteId ORDER BY v.isPinned DESC, v.createdAt DESC")
    List<Video> findByAthleteIdPinnedFirst(@Param("athleteId") String athleteId);

    /** Pinned first with category filter. */
    @Query("SELECT v FROM Video v WHERE v.athlete.id = :athleteId AND v.category = :category ORDER BY v.isPinned DESC, v.createdAt DESC")
    List<Video> findByAthleteIdAndCategoryPinnedFirst(@Param("athleteId") String athleteId, @Param("category") VideoCategory category);

    @Query("SELECT v FROM Video v WHERE v.athlete.id IN :athleteIds ORDER BY v.createdAt DESC")
    List<Video> findByAthleteIds(@Param("athleteIds") List<String> athleteIds);
}
