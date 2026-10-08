package com.example.gamify.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ResetPasswordRequest(
        @NotBlank String username,
        @NotBlank String secretAnswer,
        @NotBlank @Size(min = 6) String newPassword
) {}
