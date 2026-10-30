package com.example.gamify.dto;

/** Phone numbers are sent and stored in E.164 form: + then country code and number, e.g. +919876543210. */
public final class PhoneNumbers {

    public static final String PATTERN = "^\\+[1-9]\\d{7,14}$";
    public static final String MESSAGE = "Enter a valid phone number with country code, like +919876543210";

    private PhoneNumbers() {}
}
