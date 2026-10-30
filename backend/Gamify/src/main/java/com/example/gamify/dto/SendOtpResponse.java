package com.example.gamify.dto;

/**
 * @param expiresInSeconds how long the code works
 * @param remainingToday   more codes the number can request today
 */
public record SendOtpResponse(long expiresInSeconds, int remainingToday) {}
