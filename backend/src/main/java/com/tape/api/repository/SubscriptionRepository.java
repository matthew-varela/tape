package com.tape.api.repository;

import com.tape.api.entity.Subscription;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.Optional;

public interface SubscriptionRepository extends JpaRepository<Subscription, String> {

    Optional<Subscription> findByUserId(String userId);

    /** Deletes the user's subscription row (used for account deletion). */
    @Modifying
    @Query("DELETE FROM Subscription s WHERE s.user.id = :userId")
    void deleteByUserId(@Param("userId") String userId);
}
