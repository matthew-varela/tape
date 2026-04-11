package com.tape.api.repository;

import com.tape.api.entity.ProfileView;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.time.Instant;
import java.util.List;

public interface ProfileViewRepository extends JpaRepository<ProfileView, String> {

    @Query("SELECT pv FROM ProfileView pv WHERE pv.viewedUser.id = :userId AND pv.viewedAt >= :since ORDER BY pv.viewedAt DESC")
    List<ProfileView> findRecentViewers(@Param("userId") String userId, @Param("since") Instant since);

    @Query("SELECT COUNT(DISTINCT pv.viewer.id) FROM ProfileView pv WHERE pv.viewedUser.id = :userId AND pv.viewedAt >= :since")
    long countRecentViewers(@Param("userId") String userId, @Param("since") Instant since);
}
