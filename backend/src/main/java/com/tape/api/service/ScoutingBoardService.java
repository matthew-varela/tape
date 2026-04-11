package com.tape.api.service;

import com.tape.api.entity.ScoutingBoard;
import com.tape.api.entity.User;
import com.tape.api.repository.ScoutingBoardRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;
import java.util.List;

@Service
public class ScoutingBoardService {

    private final ScoutingBoardRepository boardRepo;
    private final UserService userService;

    public ScoutingBoardService(ScoutingBoardRepository boardRepo, UserService userService) {
        this.boardRepo = boardRepo;
        this.userService = userService;
    }

    public List<ScoutingBoard> getBoardsForUser(String ownerId) {
        return boardRepo.findByOwnerIdOrderByCreatedAtDesc(ownerId);
    }

    public ScoutingBoard createBoard(String ownerId, String name) {
        User owner = userService.getUser(ownerId);
        ScoutingBoard board = new ScoutingBoard();
        board.setOwner(owner);
        board.setName(name);
        return boardRepo.save(board);
    }

    public ScoutingBoard addAthlete(String boardId, String athleteId) {
        ScoutingBoard board = getBoard(boardId);
        User athlete = userService.getUser(athleteId);
        if (board.getAthletes().stream().noneMatch(a -> a.getId().equals(athleteId))) {
            board.getAthletes().add(athlete);
            boardRepo.save(board);
        }
        return board;
    }

    public ScoutingBoard removeAthlete(String boardId, String athleteId) {
        ScoutingBoard board = getBoard(boardId);
        board.getAthletes().removeIf(a -> a.getId().equals(athleteId));
        return boardRepo.save(board);
    }

    private ScoutingBoard getBoard(String boardId) {
        return boardRepo.findById(boardId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Board not found"));
    }
}
