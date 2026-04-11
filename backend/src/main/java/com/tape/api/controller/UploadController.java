package com.tape.api.controller;

import com.tape.api.service.S3Service;
import org.springframework.web.bind.annotation.*;
import java.util.Map;

@RestController
@RequestMapping("/api/upload")
public class UploadController {

    private final S3Service s3Service;

    public UploadController(S3Service s3Service) {
        this.s3Service = s3Service;
    }

    @GetMapping("/presigned-url")
    public Map<String, String> getPresignedUrl(@RequestParam String filename) {
        return s3Service.generatePresignedUploadUrl(filename);
    }
}
