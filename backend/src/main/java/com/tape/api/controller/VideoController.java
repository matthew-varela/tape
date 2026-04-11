package com.tape.api.controller;

import com.tape.api.dto.VideoFeedResponse;
import com.tape.api.dto.VideoPublishRequest;
import com.tape.api.entity.Video;
import com.tape.api.enums.VideoCategory;
import com.tape.api.service.VideoService;
import jakarta.validation.Valid;
import org.springframework.data.domain.Page;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/api/videos")
public class VideoController {

    private final VideoService videoService;

    public VideoController(VideoService videoService) {
        this.videoService = videoService;
    }

    @GetMapping("/feed")
    public List<VideoFeedResponse> getFeed(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size) {
        Page<Video> videos = videoService.getFeed(page, size);
        return videos.getContent().stream().map(videoService::toFeedResponse).toList();
    }

    @GetMapping
    public List<VideoFeedResponse> getVideos(
            @RequestParam String athleteId,
            @RequestParam(required = false) VideoCategory category) {
        List<Video> videos = category != null
            ? videoService.getVideosForAthlete(athleteId, category)
            : videoService.getVideosForAthlete(athleteId);
        return videos.stream().map(videoService::toFeedResponse).toList();
    }

    @GetMapping("/search")
    public List<VideoFeedResponse> searchVideos(
            @RequestParam(required = false) String position,
            @RequestParam(required = false) String state,
            @RequestParam(required = false) String sport,
            @RequestParam(required = false) Integer gradYear,
            @RequestParam(required = false) Double minGpa) {
        return videoService.getFilteredVideos(position, state, sport, gradYear, minGpa)
            .stream().map(videoService::toFeedResponse).toList();
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public VideoFeedResponse publishVideo(@Valid @RequestBody VideoPublishRequest request) {
        Video video = videoService.publishVideo(request);
        return videoService.toFeedResponse(video);
    }

    @PutMapping("/{id}/pin")
    public VideoFeedResponse togglePin(@PathVariable String id) {
        Video video = videoService.togglePin(id);
        return videoService.toFeedResponse(video);
    }
}
