package com.example.gamify.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

/** Proof of the code: [accessToken] from the MSG91 widget, or [otp] itself when testing without MSG91. */
public record LoginRequest(
        @NotBlank @Pattern(regexp = PhoneNumbers.PATTERN, message = PhoneNumbers.MESSAGE) String phoneNumber,
        String otp,
        String accessToken
) {}
