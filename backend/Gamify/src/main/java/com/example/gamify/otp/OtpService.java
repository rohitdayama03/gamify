package com.example.gamify.otp;

import com.example.gamify.entity.OtpCode;
import com.example.gamify.entity.OtpPurpose;
import com.example.gamify.exception.BadRequestException;
import com.example.gamify.exception.TooManyRequestsException;
import com.example.gamify.repository.OtpCodeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.LocalDate;
import java.time.OffsetDateTime;

/** Issues one-time sign-in codes to phone numbers and checks them. */
@Service
@RequiredArgsConstructor
@EnableConfigurationProperties({OtpProperties.class, WhatsAppProperties.class})
public class OtpService {

    private static final int CODE_LENGTH = 6;
    private static final SecureRandom RANDOM = new SecureRandom();

    private final OtpCodeRepository otpCodeRepository;
    private final PasswordEncoder passwordEncoder;
    private final WhatsAppOtpSender whatsAppOtpSender;
    private final OtpProperties properties;

    /**
     * Sends a new code for [purpose], replacing any earlier one.
     *
     * @return how many more codes the number can request today
     */
    @Transactional
    public int send(String phoneNumber, OtpPurpose purpose) {
        OffsetDateTime startOfToday = LocalDate.now(properties.zone()).atStartOfDay(properties.zone()).toOffsetDateTime();
        long sentToday = otpCodeRepository.countByPhoneNumberAndCreatedAtGreaterThanEqual(phoneNumber, startOfToday);
        if (sentToday >= properties.dailyLimit()) {
            throw new TooManyRequestsException(
                    "You've reached today's limit of " + properties.dailyLimit() + " codes for this number. Try again tomorrow.");
        }

        String code = properties.usesFixedCode() ? properties.fixedCode() : randomCode();
        otpCodeRepository.save(OtpCode.builder()
                .phoneNumber(phoneNumber)
                .purpose(purpose)
                .codeHash(passwordEncoder.encode(code))
                .expiresAt(OffsetDateTime.now().plus(properties.validity()))
                .build());

        if (!properties.usesFixedCode()) {
            whatsAppOtpSender.send(phoneNumber, code);
        }
        return (int) (properties.dailyLimit() - sentToday - 1);
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

    private static String randomCode() {
        StringBuilder code = new StringBuilder(CODE_LENGTH);
        for (int i = 0; i < CODE_LENGTH; i++) {
            code.append(RANDOM.nextInt(10));
        }
        return code.toString();
    }
}
