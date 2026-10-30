package com.example.gamify.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record LoginRequest(
        @NotBlank @Pattern(regexp = PhoneNumbers.PATTERN, message = PhoneNumbers.MESSAGE) String phoneNumber,
        @NotBlank String otp
) {}
