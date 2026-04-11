package com.tape.api.repository;

import com.tape.api.entity.Message;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface MessageRepository extends JpaRepository<Message, String> {

    List<Message> findByConversationIdOrderBySentAtAsc(String conversationId);

    long countByConversationIdAndIsReadFalseAndSenderIdNot(String conversationId, String userId);
}
