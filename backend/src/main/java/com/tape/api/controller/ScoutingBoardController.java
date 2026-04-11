package com.tape.api.controller;

import com.tape.api.entity.ScoutingBoard;
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

    @GetMapping
    public List<ScoutingBoard> getBoards(@RequestParam String ownerId) {
        return boardService.getBoardsForUser(ownerId);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ScoutingBoard createBoard(@RequestBody Map<String, String> body) {
        return boardService.createBoard(body.get("ownerId"), body.get("name"));
    }

    @PutMapping("/{id}/athletes/{athleteId}")
    public ScoutingBoard addAthlete(@PathVariable String id, @PathVariable String athleteId) {
        return boardService.addAthlete(id, athleteId);
    }

    @DeleteMapping("/{id}/athletes/{athleteId}")
    public ScoutingBoard removeAthlete(@PathVariable String id, @PathVariable String athleteId) {
        return boardService.removeAthlete(id, athleteId);
    }
}
