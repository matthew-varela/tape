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

    /**
     * Creates a new board for the authenticated caller.
     * The caller's uid is used as the owner id; client-supplied owner ids
     * in the request body are not trusted.
     */
    public ScoutingBoard createBoard(String callerUid, String name) {
        User owner = userService.getUser(callerUid);
        ScoutingBoard board = new ScoutingBoard();
        board.setOwner(owner);
        board.setName(name);
        return boardRepo.save(board);
    }

    /** Renames a board. Caller must own the board. */
    public ScoutingBoard renameBoard(String boardId, String newName, String callerUid) {
        ScoutingBoard board = getBoard(boardId);
        requireOwner(board, callerUid);
        board.setName(newName);
        boardRepo.save(board);
        return board;
    }

    /** Deletes a board. Caller must own the board. */
    public void deleteBoard(String boardId, String callerUid) {
        ScoutingBoard board = getBoard(boardId);
        requireOwner(board, callerUid);
        boardRepo.delete(board);
    }

    /** Adds an athlete to the board. Caller must own the board. */
    public ScoutingBoard addAthlete(String boardId, String athleteId, String callerUid) {
        ScoutingBoard board = getBoard(boardId);
        requireOwner(board, callerUid);
        User athlete = userService.getUser(athleteId);
        if (board.getAthletes().stream().noneMatch(a -> a.getId().equals(athleteId))) {
            board.getAthletes().add(athlete);
            boardRepo.save(board);
        }
        return board;
    }

    /** Removes an athlete from the board. Caller must own the board. */
    public ScoutingBoard removeAthlete(String boardId, String athleteId, String callerUid) {
        ScoutingBoard board = getBoard(boardId);
        requireOwner(board, callerUid);
        board.getAthletes().removeIf(a -> a.getId().equals(athleteId));
        boardRepo.save(board);
        return board;
    }

    // ── Internal ──────────────────────────────────────────────────────────────

    private ScoutingBoard getBoard(String boardId) {
        return boardRepo.findByIdWithOwner(boardId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Board not found"));
    }

    private void requireOwner(ScoutingBoard board, String callerUid) {
        if (!board.getOwner().getId().equals(callerUid)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN,
                "You do not own this scouting board");
        }
    }
}
