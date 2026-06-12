package com.tape.api.dto;

/**
 * Payload for POST /api/users/me/subscription.
 *
 * Sent by the iOS SubscriptionManager after a StoreKit event, or by a
 * future Android SubscriptionManager after a Play Billing event. The
 * server records the platform so billing history is cross-platform.
 */
public record SubscriptionSyncRequest(
    boolean active,
    String platform,
    String provider
) {
    /** Defaults platform/provider to iOS StoreKit when not specified. */
    public String effectivePlatform() {
        return platform != null ? platform : "ios";
    }

    public String effectiveProvider() {
        return provider != null ? provider : "storekit";
    }
}
