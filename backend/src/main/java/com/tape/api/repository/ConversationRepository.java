package com.tape.api.repository;

import com.tape.api.entity.Conversation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;
import java.util.Optional;

public interface ConversationRepository extends JpaRepository<Conversation, String> {

    @Query("SELECT c FROM Conversation c WHERE c.participant1.id = :userId OR c.participant2.id = :userId ORDER BY c.lastMessageDate DESC")
    List<Conversation> findByParticipant(@Param("userId") String userId);

    @Query("SELECT c FROM Conversation c WHERE (c.participant1.id = :id1 AND c.participant2.id = :id2) OR (c.participant1.id = :id2 AND c.participant2.id = :id1)")
    Optional<Conversation> findByParticipants(@Param("id1") String id1, @Param("id2") String id2);
}
