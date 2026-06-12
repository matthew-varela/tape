package com.tape.api.security;

import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseAuthException;
import com.google.firebase.auth.FirebaseToken;
import com.tape.api.config.TapeFirebaseProperties;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.List;
import org.springframework.http.MediaType;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Extracts {@code Authorization: Bearer <Firebase ID token>}, verifies it with
 * Firebase Admin, and populates {@link SecurityContextHolder}. Skips paths
 * listed in {@link TapeFirebaseProperties#getPublicPaths()}. When Firebase is
 * disabled in config, delegates without checking tokens.
 */
@Component
public class FirebaseAuthenticationFilter extends OncePerRequestFilter {

    private static final String BEARER_PREFIX = "Bearer ";

    private final TapeFirebaseProperties firebaseProperties;

    public FirebaseAuthenticationFilter(TapeFirebaseProperties firebaseProperties) {
        this.firebaseProperties = firebaseProperties;
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {

        if (!firebaseProperties.isEnabled()) {
            // In local/test mode, accept X-Test-User-ID header to simulate an authenticated user.
            // This header is never honoured when Firebase is enabled.
            String testUid = request.getHeader("X-Test-User-ID");
            if (testUid != null && !testUid.isBlank()) {
                FirebaseAuthenticationToken stubAuth = new FirebaseAuthenticationToken(null) {
                    @Override public Object getPrincipal() { return testUid; }
                    @Override public Object getCredentials() { return null; }
                };
                SecurityContextHolder.getContext().setAuthentication(stubAuth);
            }
            filterChain.doFilter(request, response);
            return;
        }

        SecurityContextHolder.clearContext();

        String path = request.getRequestURI();
        if (isPublicPath(path)) {
            filterChain.doFilter(request, response);
            return;
        }

        try {
            String header = request.getHeader("Authorization");
            if (header == null || !header.startsWith(BEARER_PREFIX)) {
                writeUnauthorized(response, "Missing or invalid Authorization header");
                return;
            }

            String idToken = header.substring(BEARER_PREFIX.length()).trim();
            if (idToken.isEmpty()) {
                writeUnauthorized(response, "Empty Bearer token");
                return;
            }

            FirebaseToken decoded = FirebaseAuth.getInstance().verifyIdToken(idToken);
            FirebaseAuthenticationToken authentication = new FirebaseAuthenticationToken(decoded);
            SecurityContextHolder.getContext().setAuthentication(authentication);
            filterChain.doFilter(request, response);
        } catch (FirebaseAuthException e) {
            writeUnauthorized(response, "Invalid or expired token");
        } finally {
            SecurityContextHolder.clearContext();
        }
    }

    private boolean isPublicPath(String path) {
        List<String> publicPaths = firebaseProperties.getPublicPaths();
        if (publicPaths == null) {
            return false;
        }
        for (String prefix : publicPaths) {
            if (prefix != null && path.startsWith(prefix)) {
                return true;
            }
        }
        return false;
    }

    private static void writeUnauthorized(HttpServletResponse response, String message) throws IOException {
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding("UTF-8");
        String escaped = message.replace("\\", "\\\\").replace("\"", "\\\"");
        response.getWriter().write("{\"message\":\"" + escaped + "\"}");
    }
}
