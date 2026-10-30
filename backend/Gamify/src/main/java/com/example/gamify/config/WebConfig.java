package com.example.gamify.config;

import com.example.gamify.controller.PlayerSearchController;
import com.example.gamify.security.AuthInterceptor;
import com.example.gamify.security.CurrentUsernameArgumentResolver;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.method.support.HandlerMethodArgumentResolver;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.util.List;

@Configuration
@RequiredArgsConstructor
public class WebConfig implements WebMvcConfigurer {

    private final CurrentUsernameArgumentResolver currentUsernameArgumentResolver;
    private final AuthInterceptor authInterceptor;

    @Value("${app.cors.allowed-origins}")
    private String[] allowedOrigins;

    @Override
    public void addArgumentResolvers(List<HandlerMethodArgumentResolver> resolvers) {
        resolvers.add(currentUsernameArgumentResolver);
    }

    // Every API needs a login token except the ones used to get one
    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(authInterceptor)
                .addPathPatterns("/api/**")
                .excludePathPatterns("/api/v1/auth/otp", "/api/v1/auth/register", "/api/v1/auth/login");
    }

    // Allows the Flutter web build to call the API; locally it's served from a random localhost port
    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**")
                .allowedOriginPatterns(allowedOrigins)
                .allowedMethods("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS")
                .allowedHeaders("*")
                .exposedHeaders(PlayerSearchController.MATCHED_GAME_HEADER);
    }
}
