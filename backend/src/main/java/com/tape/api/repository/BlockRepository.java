package com.tape.api.repository;

import com.tape.api.entity.Block;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;

public interface BlockRepository extends JpaRepository<Block, String> {

    boolean existsByBlockerIdAndBlockedId(String blockerId, String blockedId);

    void deleteByBlockerIdAndBlockedId(String blockerId, String blockedId);

    /** IDs of users the given user has blocked. */
    @Query("SELECT b.blocked.id FROM Block b WHERE b.blocker.id = :userId")
    List<String> findBlockedIds(@Param("userId") String userId);

    /** IDs of users who have blocked the given user. */
    @Query("SELECT b.blocker.id FROM Block b WHERE b.blocked.id = :userId")
    List<String> findBlockerIds(@Param("userId") String userId);

    /** Removes all block rows involving the user (used for account deletion). */
    @Modifying
    @Query("DELETE FROM Block b WHERE b.blocker.id = :userId OR b.blocked.id = :userId")
    void deleteByUser(@Param("userId") String userId);
}
