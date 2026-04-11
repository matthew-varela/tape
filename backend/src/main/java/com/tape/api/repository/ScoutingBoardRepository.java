package com.tape.api.repository;

import com.tape.api.entity.ScoutingBoard;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface ScoutingBoardRepository extends JpaRepository<ScoutingBoard, String> {

    List<ScoutingBoard> findByOwnerIdOrderByCreatedAtDesc(String ownerId);
}
