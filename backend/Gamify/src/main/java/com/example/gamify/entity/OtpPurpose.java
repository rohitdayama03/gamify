package com.example.gamify.entity;

// A code is only accepted for the step it was sent for, so a login code can't create an account
public enum OtpPurpose {
    REGISTER,
    LOGIN
}
