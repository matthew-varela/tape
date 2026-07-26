package com.tape.api.dto;

/**
 * Social counters for one profile. {@code isFollowing} is relative to the
 * authenticated caller so the client can render the follow button without a
 * second round trip.
 */
public record FollowCountsResponse(
    long followers,
    long following,
    boolean isFollowing
) {}
