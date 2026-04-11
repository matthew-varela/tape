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
}
