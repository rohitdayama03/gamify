package com.example.gamify.otp;

import com.example.gamify.entity.OtpCode;
import com.example.gamify.entity.OtpPurpose;
import com.example.gamify.entity.OtpRequest;
import com.example.gamify.exception.BadRequestException;
import com.example.gamify.exception.TooManyRequestsException;
import com.example.gamify.repository.OtpCodeRepository;
import com.example.gamify.repository.OtpRequestRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.LocalDate;
import java.time.OffsetDateTime;

/**
 * Sign-in codes the server issues itself, for testing without MSG91: every code is app.otp.fixed-code and
 * nothing is sent. Once MSG91 is set up, the app gets its codes from MSG91 and this isn't used.
 */
@Slf4j
@Service
@RequiredArgsConstructor
@EnableConfigurationProperties({OtpProperties.class, Msg91Properties.class})
public class OtpService {

    private final OtpCodeRepository otpCodeRepository;
    private final OtpRequestRepository otpRequestRepository;
    private final PasswordEncoder passwordEncoder;
    private final OtpProperties properties;
    private final Msg91Properties msg91Properties;

    @EventListener(ApplicationReadyEvent.class)
    public void warnIfSignInOff() {
        if (msg91Properties.enabled()) return;
        if (properties.usesFixedCode()) {
            log.warn("MSG91 is not set up: every sign-in code is OTP_FIXED_CODE. For local testing only");
        } else {
            log.error("MSG91 is not set up and OTP_FIXED_CODE is empty: nobody can sign in or register");
        }
    }

    /**
     * Counts a request for a code to [phoneNumber], whether MSG91 or this server sends it. Refuses it when the
     * number asked too recently or has used up today's requests. MSG91's resends of the same code aren't counted.
     *
     * @return how many more codes the number can request today
     */
    @Transactional
    public int recordRequest(String phoneNumber) {
        otpRequestRepository.lockPhoneNumber(phoneNumber);

        OffsetDateTime now = OffsetDateTime.now();
        otpRequestRepository.findFirstByPhoneNumberOrderByCreatedAtDesc(phoneNumber).ifPresent(last -> {
            long wait = Duration.between(now, last.getCreatedAt().plus(properties.minInterval())).toSeconds();
            if (wait > 0) {
                throw new TooManyRequestsException("Please wait " + wait + " seconds before requesting another code.");
            }
        });

        OffsetDateTime startOfToday = LocalDate.now(properties.zone()).atStartOfDay(properties.zone()).toOffsetDateTime();
        long sentToday = otpRequestRepository.countByPhoneNumberAndCreatedAtGreaterThanEqual(phoneNumber, startOfToday);
        if (sentToday >= properties.dailyLimit()) {
            throw new TooManyRequestsException(
                    "You've reached today's limit of " + properties.dailyLimit() + " codes for this number. Try again tomorrow.");
        }

        otpRequestRepository.save(OtpRequest.builder().phoneNumber(phoneNumber).build());
        return (int) (properties.dailyLimit() - sentToday - 1);
    }

    /**
     * Issues the fixed testing code for [purpose], replacing any earlier one, after counting the request.
     *
     * @return how many more codes the number can request today
     */
    @Transactional
    public int send(String phoneNumber, OtpPurpose purpose) {
        if (!properties.usesFixedCode()) {
            log.error("Sign-in codes are not set up: set MSG91_WIDGET_ID, MSG91_TOKEN_AUTH and MSG91_AUTH_KEY");
            throw new IllegalStateException("Sign-in is unavailable right now. Please try again later.");
        }
        int remainingToday = recordRequest(phoneNumber);

        otpCodeRepository.save(OtpCode.builder()
                .phoneNumber(phoneNumber)
                .purpose(purpose)
                .codeHash(passwordEncoder.encode(properties.fixedCode()))
                .expiresAt(OffsetDateTime.now().plus(properties.validity()))
                .build());
        return remainingToday;
    }

    // The limits only look back to the start of today, so older records are no longer needed
    @Scheduled(cron = "0 30 3 * * *", zone = "${app.otp.zone}")
    @Transactional
    public void deleteOldRecords() {
        OffsetDateTime before = OffsetDateTime.now().minusDays(2);
        int requests = otpRequestRepository.deleteCreatedBefore(before);
        int codes = otpCodeRepository.deleteCreatedBefore(before);
        log.info("Deleted {} old code requests and {} old codes", requests, codes);
    }

    /**
     * Checks [code] against the latest code sent to the number for [purpose] and uses it up when it matches.
     * Runs in its own transaction so a wrong guess is counted even when the caller rolls back.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW, noRollbackFor = BadRequestException.class)
    public void verify(String phoneNumber, OtpPurpose purpose, String code) {
        OtpCode otp = otpCodeRepository.findFirstByPhoneNumberAndPurposeAndUsedFalseOrderByCreatedAtDesc(phoneNumber, purpose)
                .orElseThrow(() -> new BadRequestException("Request a code first"));

        if (otp.getExpiresAt().isBefore(OffsetDateTime.now())) {
            throw new BadRequestException("This code has expired. Request a new one.");
        }
        if (otp.getAttempts() >= properties.maxAttempts()) {
            throw new BadRequestException("Too many wrong tries. Request a new code.");
        }
        if (code == null || !passwordEncoder.matches(code.trim(), otp.getCodeHash())) {
            otp.setAttempts(otp.getAttempts() + 1);
            otpCodeRepository.save(otp);
            throw new BadRequestException("Incorrect code");
        }

        otp.setUsed(true);
        otpCodeRepository.save(otp);
    }

    // Logs keep only the last 4 digits of a phone number
    static String mask(String phoneNumber) {
        return phoneNumber.length() <= 4 ? "****" : "*".repeat(phoneNumber.length() - 4) + phoneNumber.substring(phoneNumber.length() - 4);
    }
}
