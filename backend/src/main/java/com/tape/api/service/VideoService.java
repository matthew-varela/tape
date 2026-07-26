package com.tape.api.service;

import com.tape.api.dto.VideoFeedResponse;
import com.tape.api.dto.VideoPublishRequest;
import com.tape.api.entity.User;
import com.tape.api.entity.Video;
import com.tape.api.enums.SubscriptionTier;
import com.tape.api.enums.VideoCategory;
import com.tape.api.repository.FollowRepository;
import com.tape.api.repository.VideoRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import java.util.List;
import java.util.Set;

@Service
public class VideoService {

    private final VideoRepository videoRepo;
    private final UserService userService;
    private final ModerationService moderationService;
    private final FollowRepository followRepo;

    public VideoService(VideoRepository videoRepo,
                        UserService userService,
                        ModerationService moderationService,
                        FollowRepository followRepo) {
        this.videoRepo = videoRepo;
        this.userService = userService;
        this.moderationService = moderationService;
        this.followRepo = followRepo;
    }

    /** Feed for the given caller, excluding any blocked users in either direction. */
    public Page<Video> getFeed(int page, int size, String callerUid) {
        PageRequest pageRequest = PageRequest.of(page, size);
        Set<String> hidden = moderationService.getHiddenUserIds(callerUid);
        if (hidden.isEmpty()) {
            return videoRepo.findAllByOrderByCreatedAtDesc(pageRequest);
        }
        return videoRepo.findFeedExcluding(hidden, pageRequest);
    }

    /**
     * Feed limited to athletes the caller follows. Returns an empty page when
     * the caller follows nobody so the client can show a "find people to
     * follow" empty state instead of silently falling back to discover.
     */
    public Page<Video> getFollowingFeed(int page, int size, String callerUid) {
        PageRequest pageRequest = PageRequest.of(page, size);
        Set<String> hidden = moderationService.getHiddenUserIds(callerUid);
        List<String> followed = followRepo.findFolloweeIds(callerUid).stream()
            .filter(id -> !hidden.contains(id))
            .toList();
        if (followed.isEmpty()) {
            return Page.empty(pageRequest);
        }
        return videoRepo.findFeedByAthleteIds(followed, pageRequest);
    }

    /**
     * Records one play. Views are counted per play, not per unique viewer, so
     * the same person rewatching a clip ten times is ten views.
     */
    @Transactional
    public void recordView(String videoId) {
        if (videoRepo.incrementViewCount(videoId) == 0) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Video not found");
        }
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

    public List<Video> getFilteredVideos(String position, String state, String sport, Integer gradYear, Double minGpa, String callerUid) {
        List<User> athletes = userService.searchAthletes(position, state, sport, gradYear, minGpa);
        Set<String> hidden = moderationService.getHiddenUserIds(callerUid);
        List<String> athleteIds = athletes.stream()
            .map(User::getId)
            .filter(id -> !hidden.contains(id))
            .toList();
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
            v.getViewCount(),
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
