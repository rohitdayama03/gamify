package com.example.gamify.otp;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.time.Duration;
import java.time.ZoneId;

/**
 * Sign-in codes (app.otp.*).
 *
 * @param fixedCode   when set and MSG91 isn't, every code is this value and nothing is sent; for local
 *                    testing only (OTP_FIXED_CODE). Ignored once app.msg91.* is set
 * @param dailyLimit  most codes one phone number can request per day (MSG91's resends of a code aren't counted)
 * @param minInterval shortest wait between two code requests for the same number
 * @param validity    how long a code works after it is sent
 * @param maxAttempts wrong guesses allowed before a code stops working
 * @param zone        time zone whose midnight resets the daily limit
 */
@ConfigurationProperties(prefix = "app.otp")
public record OtpProperties(String fixedCode, int dailyLimit, Duration minInterval, Duration validity, int maxAttempts, ZoneId zone) {

    public boolean usesFixedCode() {
        return fixedCode != null && !fixedCode.isBlank();
    }
}
