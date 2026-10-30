package com.example.gamify.security;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

/**
 * Rejects API calls without a valid login token with 401. Registered for /api/** except the sign-in
 * endpoints (see WebConfig), so an endpoint is protected even if it never asks who the caller is.
 */
@Component
@RequiredArgsConstructor
public class AuthInterceptor implements HandlerInterceptor {

    private final CurrentUsernameArgumentResolver currentUsernameResolver;

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        // Browsers send CORS preflights without the token
        if (HttpMethod.OPTIONS.matches(request.getMethod())) {
            return true;
        }
        currentUsernameResolver.requireUsername(request.getHeader(HttpHeaders.AUTHORIZATION));
        return true;
    }
}
