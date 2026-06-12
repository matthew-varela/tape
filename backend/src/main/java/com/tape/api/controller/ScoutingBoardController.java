package com.tape.api.controller;

import com.tape.api.entity.ScoutingBoard;
import com.tape.api.security.SecurityUtils;
import com.tape.api.service.ScoutingBoardService;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/scouting-boards")
public class ScoutingBoardController {

    private final ScoutingBoardService boardService;

    public ScoutingBoardController(ScoutingBoardService boardService) {
        this.boardService = boardService;
    }

    /**
     * Returns boards for the authenticated caller.
     * The {@code ownerId} query param is accepted for backward compat with
     * existing clients but the server always uses the token uid.
     */
    @GetMapping
    public List<ScoutingBoard> getBoards(@RequestParam(required = false) String ownerId) {
        String uid = SecurityUtils.requireFirebaseUid();
        return boardService.getBoardsForUser(uid);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ScoutingBoard createBoard(@RequestBody Map<String, String> body) {
        String uid = SecurityUtils.requireFirebaseUid();
        return boardService.createBoard(uid, body.get("name"));
    }

    @PatchMapping("/{id}")
    public ScoutingBoard renameBoard(@PathVariable String id, @RequestBody Map<String, String> body) {
        String uid = SecurityUtils.requireFirebaseUid();
        return boardService.renameBoard(id, body.get("name"), uid);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteBoard(@PathVariable String id) {
        String uid = SecurityUtils.requireFirebaseUid();
        boardService.deleteBoard(id, uid);
    }

    @PostMapping("/{id}/athletes")
    public ScoutingBoard addAthlete(@PathVariable String id, @RequestBody Map<String, String> body) {
        String uid = SecurityUtils.requireFirebaseUid();
        return boardService.addAthlete(id, body.get("athleteId"), uid);
    }

    @DeleteMapping("/{id}/athletes/{athleteId}")
    public ScoutingBoard removeAthlete(@PathVariable String id, @PathVariable String athleteId) {
        String uid = SecurityUtils.requireFirebaseUid();
        return boardService.removeAthlete(id, athleteId, uid);
    }
}
