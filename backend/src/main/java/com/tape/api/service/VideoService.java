package com.tape.api.service;

import com.tape.api.dto.VideoFeedResponse;
import com.tape.api.dto.VideoPublishRequest;
import com.tape.api.entity.User;
import com.tape.api.entity.Video;
import com.tape.api.enums.VideoCategory;
import com.tape.api.repository.VideoRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;
import java.util.List;

@Service
public class VideoService {

    private final VideoRepository videoRepo;
    private final UserService userService;

    public VideoService(VideoRepository videoRepo, UserService userService) {
        this.videoRepo = videoRepo;
        this.userService = userService;
    }

    public Page<Video> getFeed(int page, int size) {
        return videoRepo.findAllByOrderByCreatedAtDesc(PageRequest.of(page, size));
    }

    public List<Video> getVideosForAthlete(String athleteId) {
        return videoRepo.findByAthleteIdOrderByCreatedAtDesc(athleteId);
    }

    public List<Video> getVideosForAthlete(String athleteId, VideoCategory category) {
        return videoRepo.findByAthleteIdAndCategoryOrderByCreatedAtDesc(athleteId, category);
    }

    public List<Video> getFilteredVideos(String position, String state, String sport, Integer gradYear, Double minGpa) {
        List<User> athletes = userService.searchAthletes(position, state, sport, gradYear, minGpa);
        List<String> athleteIds = athletes.stream().map(User::getId).toList();
        if (athleteIds.isEmpty()) return List.of();
        return videoRepo.findByAthleteIds(athleteIds);
    }

    public Video publishVideo(VideoPublishRequest req) {
        User athlete = userService.getUser(req.athleteId());
        Video video = new Video();
        video.setAthlete(athlete);
        video.setVideoUrl(req.videoUrl());
        video.setThumbnailUrl(req.thumbnailUrl());
        video.setCategory(req.category());
        video.setTags(req.tags());
        video.setCaption(req.caption());
        return videoRepo.save(video);
    }

    public Video togglePin(String videoId) {
        Video video = videoRepo.findById(videoId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Video not found"));
        video.setPinned(!video.isPinned());
        return videoRepo.save(video);
    }

    public VideoFeedResponse toFeedResponse(Video v) {
        User a = v.getAthlete();
        return new VideoFeedResponse(
            v.getId(),
            a.getId(),
            v.getVideoUrl(),
            v.getThumbnailUrl(),
            v.getCategory(),
            v.getTags(),
            v.getCaption(),
            v.getCreatedAt(),
            v.isPinned(),
            a.getDisplayName(),
            a.getHighSchool(),
            a.getGradYear() != null ? a.getGradYear() : 0,
            a.getPosition(),
            a.getProfileImageUrl()
        );
    }
}
