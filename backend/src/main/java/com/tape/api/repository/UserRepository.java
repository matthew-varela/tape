package com.tape.api.repository;

import com.tape.api.entity.User;
import com.tape.api.enums.UserRole;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;
import java.util.Optional;

public interface UserRepository extends JpaRepository<User, String> {

    Optional<User> findByEmail(String email);

    List<User> findByRole(UserRole role);

    /**
     * Athlete-specific structured search used by the video search feature.
     * All parameters are optional (pass null to skip that filter).
     */
    @Query("SELECT u FROM User u WHERE u.role = 'ATHLETE'" +
           " AND (:position IS NULL OR u.position = :position)" +
           " AND (:state IS NULL OR u.state = :state)" +
           " AND (:sport IS NULL OR u.sport = :sport)" +
           " AND (:gradYear IS NULL OR u.gradYear = :gradYear)" +
           " AND (:minGpa IS NULL OR u.gpa >= :minGpa)")
    List<User> searchAthletes(
        @Param("position") String position,
        @Param("state") String state,
        @Param("sport") String sport,
        @Param("gradYear") Integer gradYear,
        @Param("minGpa") Double minGpa
    );

    /**
     * General user search used by GET /api/users/search.
     * Supports optional free-text on displayName / highSchool / sport,
     * optional role filter, and optional structured filters.
     */
    @Query("SELECT u FROM User u WHERE" +
           " (:role IS NULL OR u.role = :role)" +
           " AND (:q IS NULL OR" +
           "       LOWER(u.displayName) LIKE LOWER(CONCAT('%', :q, '%'))" +
           "    OR LOWER(COALESCE(u.highSchool, '')) LIKE LOWER(CONCAT('%', :q, '%'))" +
           "    OR LOWER(COALESCE(u.sport, '')) LIKE LOWER(CONCAT('%', :q, '%')))" +
           " AND (:position IS NULL OR u.position = :position)" +
           " AND (:state IS NULL OR u.state = :state)" +
           " AND (:sport IS NULL OR u.sport = :sport)")
    List<User> searchUsers(
        @Param("role") UserRole role,
        @Param("q") String q,
        @Param("position") String position,
        @Param("state") String state,
        @Param("sport") String sport
    );
}
