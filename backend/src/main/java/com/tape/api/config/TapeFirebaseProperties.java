package com.tape.api.config;

import java.util.ArrayList;
import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * When {@code enabled} is true, the app initializes Firebase Admin (using
 * {@code GOOGLE_APPLICATION_CREDENTIALS} or Application Default Credentials)
 * and enforces Bearer-token auth on API routes except {@link #publicPaths}.
 */
@ConfigurationProperties(prefix = "tape.firebase")
public class TapeFirebaseProperties {

    /**
     * Set {@code TAPE_FIREBASE_ENABLED=true} on Render alongside the secret file
     * and {@code GOOGLE_APPLICATION_CREDENTIALS}. Local/test uses {@code false}.
     */
    private boolean enabled = false;

    /**
     * Request path prefixes (e.g. {@code /api/health}) that skip Firebase verification.
     */
    private List<String> publicPaths = new ArrayList<>(List.of("/api/health"));

    public boolean isEnabled() {
        return enabled;
    }

    public void setEnabled(boolean enabled) {
        this.enabled = enabled;
    }

    public List<String> getPublicPaths() {
        return publicPaths;
    }

    public void setPublicPaths(List<String> publicPaths) {
        this.publicPaths = publicPaths;
    }
}
