package com.tape.api.controller;

import com.tape.api.dto.SignUpRequest;
import com.tape.api.entity.User;
import com.tape.api.service.UserService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final UserService userService;

    public AuthController(UserService userService) {
        this.userService = userService;
    }

    @PostMapping("/signup")
    @ResponseStatus(HttpStatus.CREATED)
    public User signUp(@Valid @RequestBody SignUpRequest request) {
        return userService.createUser(request);
    }

    @PostMapping("/signin")
    public User signIn(@RequestBody java.util.Map<String, String> body) {
        String email = body.get("email");
        return userService.getUserByEmail(email);
    }

    @GetMapping("/me")
    public User me(@RequestParam String userId) {
        return userService.getUser(userId);
    }
}
