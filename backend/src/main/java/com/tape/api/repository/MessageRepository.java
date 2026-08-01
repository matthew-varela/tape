package com.tape.api.repository;

import com.tape.api.entity.Message;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;

public interface MessageRepository extends JpaRepository<Message, String> {

    List<Message> findByConversationIdOrderBySentAtAsc(String conversationId);

    long countByConversationIdAndIsReadFalseAndSenderIdNot(String conversationId, String userId);

    /**
     * Marks everything the *other* participant sent in this thread as read.
     * Excluding the caller's own messages keeps a sender from marking their
     * own message read and falsely showing themselves a read receipt.
     *
     * Returns the number of rows updated so the caller can skip a redundant
     * refresh when nothing changed.
     */
    @Modifying
    @Query("UPDATE Message m SET m.isRead = true " +
           "WHERE m.conversation.id = :conversationId " +
           "AND m.sender.id <> :readerId " +
           "AND m.isRead = false")
    int markReadByReader(@Param("conversationId") String conversationId,
                         @Param("readerId") String readerId);

    /**
     * Deletes every message in any conversation the user participates in. A
     * message's sender is always a participant, so this also covers messages
     * the user sent. Must run before deleting the user's conversations.
     */
    @Modifying
    @Query("DELETE FROM Message m WHERE m.conversation.id IN " +
           "(SELECT c.id FROM Conversation c WHERE c.participant1.id = :userId OR c.participant2.id = :userId)")
    void deleteByParticipant(@Param("userId") String userId);
}
