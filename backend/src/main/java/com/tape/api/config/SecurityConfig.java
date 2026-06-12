package com.tape.api.config;

import com.tape.api.security.FirebaseAuthenticationFilter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

/**
 * When {@code tape.firebase.enabled=true}, all requests except {@linkplain
 * TapeFirebaseProperties#getPublicPaths() public paths} require a valid
 * Firebase Bearer token. When disabled (local tests), all routes are open.
 */
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain securityFilterChain(
            HttpSecurity http,
            FirebaseAuthenticationFilter firebaseAuthenticationFilter,
            TapeFirebaseProperties tapeFirebaseProperties
    ) throws Exception {

        http.csrf(AbstractHttpConfigurer::disable)
                .sessionManagement(session ->
                        session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .httpBasic(AbstractHttpConfigurer::disable)
                .formLogin(AbstractHttpConfigurer::disable);

        if (tapeFirebaseProperties.isEnabled()) {
            String[] publicPatterns = tapeFirebaseProperties.getPublicPaths().toArray(new String[0]);
            http.authorizeHttpRequests(auth -> {
                if (publicPatterns.length > 0) {
                    auth.requestMatchers(publicPatterns).permitAll();
                }
                auth.anyRequest().authenticated();
            });
            http.addFilterBefore(firebaseAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);
        } else {
            http.authorizeHttpRequests(auth -> auth.anyRequest().permitAll());
        }

        return http.build();
    }
}
