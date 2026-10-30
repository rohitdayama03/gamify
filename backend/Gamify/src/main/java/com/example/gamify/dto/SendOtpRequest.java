package com.example.gamify.dto;

import com.example.gamify.entity.OtpPurpose;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * For REGISTER, the username the player chose is checked first, so a code isn't spent on an
 * account that can't be created.
 */
public record SendOtpRequest(
        @NotBlank @Pattern(regexp = PhoneNumbers.PATTERN, message = PhoneNumbers.MESSAGE) String phoneNumber,
        @NotNull OtpPurpose purpose,
        @Size(min = 3, max = 50) String username
) {}
