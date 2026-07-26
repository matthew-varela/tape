package com.tape.api.repository;

import com.tape.api.entity.Report;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ReportRepository extends JpaRepository<Report, String> {

    /**
     * Deletes reports filed BY the user (whose reporter_id FK would otherwise
     * dangle). Reports ABOUT the user are kept for moderation history because
     * {@code targetId} is a plain string, not a foreign key.
     */
    @Modifying
    @Query("DELETE FROM Report r WHERE r.reporter.id = :userId")
    void deleteByReporterId(@Param("userId") String userId);
}
