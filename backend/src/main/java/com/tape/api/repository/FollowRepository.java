package com.tape.api.repository;

import com.tape.api.entity.Follow;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;

public interface FollowRepository extends JpaRepository<Follow, String> {

    boolean existsByFollowerIdAndFolloweeId(String followerId, String followeeId);

    void deleteByFollowerIdAndFolloweeId(String followerId, String followeeId);

    /** IDs of the users the given user follows. Drives the Following feed. */
    @Query("SELECT f.followee.id FROM Follow f WHERE f.follower.id = :userId")
    List<String> findFolloweeIds(@Param("userId") String userId);

    /** IDs of the users who follow the given user. */
    @Query("SELECT f.follower.id FROM Follow f WHERE f.followee.id = :userId")
    List<String> findFollowerIds(@Param("userId") String userId);

    /** How many accounts the given user follows. */
    long countByFollowerId(String followerId);

    /** How many accounts follow the given user. */
    long countByFolloweeId(String followeeId);

    /** Removes every edge touching the user (used for account deletion). */
    @Modifying
    @Query("DELETE FROM Follow f WHERE f.follower.id = :userId OR f.followee.id = :userId")
    void deleteByUser(@Param("userId") String userId);
}
