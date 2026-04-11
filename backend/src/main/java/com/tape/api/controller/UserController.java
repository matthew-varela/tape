package com.tape.api.controller;

import com.tape.api.entity.User;
import com.tape.api.enums.UserRole;
import com.tape.api.service.UserService;
import org.springframework.web.bind.annotation.*;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/users")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @GetMapping("/{id}")
    public User getUser(@PathVariable String id) {
        return userService.getUser(id);
    }

    @GetMapping
    public List<User> getUsersByRole(@RequestParam UserRole role) {
        return userService.getUsersByRole(role);
    }

    @PutMapping("/{id}")
    public User updateUser(@PathVariable String id, @RequestBody User updates) {
        return userService.updateUser(id, updates);
    }

    @GetMapping("/{id}/viewers")
    public List<User> getProfileViewers(@PathVariable String id) {
        return userService.getProfileViewers(id);
    }

    @GetMapping("/{id}/view-count")
    public Map<String, Long> getProfileViewCount(@PathVariable String id) {
        return Map.of("count", userService.getProfileViewCount(id));
    }

    @PostMapping("/{id}/views")
    public void recordProfileView(@PathVariable String id, @RequestBody Map<String, String> body) {
        userService.recordProfileView(id, body.get("viewerId"));
    }
}
