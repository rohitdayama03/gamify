package com.example.gamify.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.io.Decoders;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.security.Key;
import java.util.Date;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

@Component
public class JwtUtils {

    // 256-bit secret key configured in application.yml
    @Value("${app.jwt.secret:404E635266556A586E3272357538782F413F4428472B4B6250655368566D5971}")
    private String jwtSecret;

    // Default expiration: 24 hours in milliseconds
    @Value("${app.jwt.expiration-ms:86400000}")
    private long jwtExpirationMs;

    // In-memory blacklist for invalidated tokens during logout
    private final Set<String> blacklistedTokens = ConcurrentHashMap.newKeySet();

    private Key getSigningKey() {
        byte[] keyBytes = Decoders.BASE64.decode(jwtSecret);
        return Keys.hmacShaKeyFor(keyBytes);
    }

    /**
     * Generates a signed JWT token containing the username as subject.
     */
    public String generateToken(String username) {
        Date now = new Date();
        Date expiryDate = new Date(now.getTime() + jwtExpirationMs);

        return Jwts.builder()
                .setSubject(username)
                .setIssuedAt(now)
                .setExpiration(expiryDate)
                .signWith(getSigningKey(), SignatureAlgorithm.HS256)
                .compact();
    }

    /**
     * Extracts username from the JWT token.
     */
    public String getUsernameFromToken(String token) {
        Claims claims = Jwts.parserBuilder()
                .setSigningKey(getSigningKey())
                .build()
                .parseClaimsJws(token)
                .getBody();

        return claims.getSubject();
    }

    /**
     * Validates token signature, expiration, and blacklist status.
     */
    public boolean validateToken(String token) {
        if (blacklistedTokens.contains(token)) {
            return false;
        }

        try {
            Jwts.parserBuilder()
                    .setSigningKey(getSigningKey())
                    .build()
                    .parseClaimsJws(token);
            return true;
        } catch (JwtException | IllegalArgumentException e) {
            return false;
        }
    }

    /**
     * Blacklists token on logout.
     */
    public void invalidateToken(String token) {
        blacklistedTokens.add(token);
    }
}