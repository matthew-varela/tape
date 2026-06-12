package com.tape.api.service;

import com.tape.api.dto.VideoFeedResponse;
import com.tape.api.dto.VideoPublishRequest;
import com.tape.api.entity.User;
import com.tape.api.entity.Video;
import com.tape.api.enums.SubscriptionTier;
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

    /**
     * Returns an athlete's videos sorted pinned-first, then newest.
     * This matches the iOS ProfileViewModel local sort order so both clients
     * see the same ordering without client-side re-sorting.
     */
    public List<Video> getVideosForAthlete(String athleteId) {
        return videoRepo.findByAthleteIdPinnedFirst(athleteId);
    }

    public List<Video> getVideosForAthlete(String athleteId, VideoCategory category) {
        return videoRepo.findByAthleteIdAndCategoryPinnedFirst(athleteId, category);
    }

    public List<Video> getFilteredVideos(String position, String state, String sport, Integer gradYear, Double minGpa) {
        List<User> athletes = userService.searchAthletes(position, state, sport, gradYear, minGpa);
        List<String> athleteIds = athletes.stream().map(User::getId).toList();
        if (athleteIds.isEmpty()) return List.of();
        return videoRepo.findByAthleteIds(athleteIds);
    }

    /**
     * Persists video metadata. The {@code athleteId} from the request body is
     * ignored; the authenticated caller (an ATHLETE) is the owner.
     */
    public Video publishVideo(VideoPublishRequest req, String callerUid) {
        User athlete = userService.getUser(callerUid);
        Video video = new Video();
        video.setAthlete(athlete);
        video.setVideoUrl(req.videoUrl());
        video.setThumbnailUrl(req.thumbnailUrl());
        video.setCategory(req.category());
        video.setTags(req.tags());
        video.setCaption(req.caption());
        return videoRepo.save(video);
    }

    /**
     * Pins a video to the top of the athlete's profile grid.
     * Requires the caller to be PRO and own the video.
     */
    public Video pinVideo(String videoId, String callerUid) {
        return setPinned(videoId, callerUid, true);
    }

    /**
     * Removes the pin from a video.
     * Requires the caller to be PRO and own the video.
     */
    public Video unpinVideo(String videoId, String callerUid) {
        return setPinned(videoId, callerUid, false);
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

    // ── Internal ──────────────────────────────────────────────────────────────

    private Video setPinned(String videoId, String callerUid, boolean pinned) {
        Video video = videoRepo.findById(videoId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Video not found"));

        // Ownership check: only the athlete who owns the video may pin/unpin it.
        if (!video.getAthlete().getId().equals(callerUid)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "You do not own this video");
        }

        // Pro gate: pin/unpin is a Pro feature.
        User caller = userService.getUser(callerUid);
        if (caller.getTier() != SubscriptionTier.PRO) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN,
                "A Pro subscription is required to pin videos");
        }

        video.setPinned(pinned);
        return videoRepo.save(video);
    }
}
