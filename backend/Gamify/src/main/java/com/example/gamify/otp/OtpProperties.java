package com.example.gamify.otp;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.time.Duration;
import java.time.ZoneId;

/**
 * Sign-in codes (app.otp.*).
 *
 * @param fixedCode   when set, every code is this value and nothing is sent on WhatsApp; for testing until
 *                    the WhatsApp API is connected. Leave blank to generate and send real codes.
 * @param dailyLimit  most codes one phone number can request per day
 * @param validity    how long a code works after it is sent
 * @param maxAttempts wrong guesses allowed before a code stops working
 * @param zone        time zone whose midnight resets the daily limit
 */
@ConfigurationProperties(prefix = "app.otp")
public record OtpProperties(String fixedCode, int dailyLimit, Duration validity, int maxAttempts, ZoneId zone) {

    public boolean usesFixedCode() {
        return fixedCode != null && !fixedCode.isBlank();
    }
}
