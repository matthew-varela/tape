package com.tape.api.repository;

import com.tape.api.entity.Bookmark;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;

public interface BookmarkRepository extends JpaRepository<Bookmark, String> {

    List<Bookmark> findByUserIdOrderByCreatedAtDesc(String userId);

    Optional<Bookmark> findByUserIdAndVideoId(String userId, String videoId);

    void deleteByUserIdAndVideoId(String userId, String videoId);

    boolean existsByUserIdAndVideoId(String userId, String videoId);
}
