package com.tape.api.repository;

import com.tape.api.entity.Video;
import com.tape.api.enums.VideoCategory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.Collection;
import java.util.List;

public interface VideoRepository extends JpaRepository<Video, String> {

    Page<Video> findAllByOrderByCreatedAtDesc(Pageable pageable);

    /** Feed page that excludes videos from a set of hidden (blocked) athletes. */
    @Query("SELECT v FROM Video v WHERE v.athlete.id NOT IN :excluded ORDER BY v.createdAt DESC")
    Page<Video> findFeedExcluding(@Param("excluded") Collection<String> excluded, Pageable pageable);

    /** Pinned videos first, then newest — matches iOS ProfileViewModel sort order. */
    @Query("SELECT v FROM Video v WHERE v.athlete.id = :athleteId ORDER BY v.isPinned DESC, v.createdAt DESC")
    List<Video> findByAthleteIdPinnedFirst(@Param("athleteId") String athleteId);

    /** Pinned first with category filter. */
    @Query("SELECT v FROM Video v WHERE v.athlete.id = :athleteId AND v.category = :category ORDER BY v.isPinned DESC, v.createdAt DESC")
    List<Video> findByAthleteIdAndCategoryPinnedFirst(@Param("athleteId") String athleteId, @Param("category") VideoCategory category);

    @Query("SELECT v FROM Video v WHERE v.athlete.id IN :athleteIds ORDER BY v.createdAt DESC")
    List<Video> findByAthleteIds(@Param("athleteIds") List<String> athleteIds);

    /**
     * Paged feed restricted to a set of athletes. Callers must pass a non-empty
     * collection — JPQL {@code IN ()} is invalid on an empty list.
     */
    @Query("SELECT v FROM Video v WHERE v.athlete.id IN :athleteIds ORDER BY v.createdAt DESC")
    Page<Video> findFeedByAthleteIds(@Param("athleteIds") Collection<String> athleteIds, Pageable pageable);

    /**
     * Increments the play counter in a single statement so concurrent viewers
     * can't clobber each other the way a read-modify-write would.
     */
    @Modifying
    @Query("UPDATE Video v SET v.viewCount = v.viewCount + 1 WHERE v.id = :videoId")
    int incrementViewCount(@Param("videoId") String videoId);

    /**
     * Deletes the @ElementCollection tag rows for an athlete's videos. JPQL bulk
     * deletes do not cascade to element-collection tables, so this native query
     * must run before {@link #deleteByAthleteId(String)} during account deletion.
     */
    @Modifying
    @Query(value = "DELETE FROM video_tags WHERE video_id IN (SELECT id FROM videos WHERE athlete_id = :athleteId)",
           nativeQuery = true)
    void deleteTagsByAthleteId(@Param("athleteId") String athleteId);

    /** Deletes all videos owned by an athlete (used for account deletion). */
    @Modifying
    @Query("DELETE FROM Video v WHERE v.athlete.id = :athleteId")
    void deleteByAthleteId(@Param("athleteId") String athleteId);
}
