package com.tape.api.controller;

import com.tape.api.dto.VideoFeedResponse;
import com.tape.api.dto.VideoPublishRequest;
import com.tape.api.entity.Video;
import com.tape.api.enums.VideoCategory;
import com.tape.api.security.SecurityUtils;
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
        String uid = SecurityUtils.requireFirebaseUid();
        Page<Video> videos = videoService.getFeed(page, size, uid);
        return videos.getContent().stream().map(videoService::toFeedResponse).toList();
    }

    /** Feed restricted to athletes the caller follows. */
    @GetMapping("/feed/following")
    public List<VideoFeedResponse> getFollowingFeed(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size) {
        String uid = SecurityUtils.requireFirebaseUid();
        Page<Video> videos = videoService.getFollowingFeed(page, size, uid);
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
        String uid = SecurityUtils.requireFirebaseUid();
        return videoService.getFilteredVideos(position, state, sport, gradYear, minGpa, uid)
            .stream().map(videoService::toFeedResponse).toList();
    }

    /**
     * Publishes video metadata. The authenticated caller must be an ATHLETE;
     * any {@code athleteId} body field is ignored — the token uid is the owner.
     */
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public VideoFeedResponse publishVideo(@Valid @RequestBody VideoPublishRequest request) {
        String uid = SecurityUtils.requireFirebaseUid();
        Video video = videoService.publishVideo(request, uid);
        return videoService.toFeedResponse(video);
    }

    /** Records one play. Self-views are ignored server-side. */
    @PostMapping("/{id}/view")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void recordView(@PathVariable String id) {
        String uid = SecurityUtils.requireFirebaseUid();
        videoService.recordView(id, uid);
    }

    /** Pro feature. Caller must own the video. */
    @PutMapping("/{id}/pin")
    public VideoFeedResponse pinVideo(@PathVariable String id) {
        String uid = SecurityUtils.requireFirebaseUid();
        Video video = videoService.pinVideo(id, uid);
        return videoService.toFeedResponse(video);
    }

    /** Pro feature. Caller must own the video. */
    @PutMapping("/{id}/unpin")
    public VideoFeedResponse unpinVideo(@PathVariable String id) {
        String uid = SecurityUtils.requireFirebaseUid();
        Video video = videoService.unpinVideo(id, uid);
        return videoService.toFeedResponse(video);
    }
}
