package com.example.gamify.otp;

import com.example.gamify.exception.BadRequestException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import java.time.Duration;
import java.util.Map;

/** Confirms with MSG91 that the app really verified a code, and for which phone number. */
@Slf4j
@Component
public class Msg91TokenVerifier {

    private final Msg91Properties properties;
    private final RestClient client;

    public Msg91TokenVerifier(Msg91Properties properties) {
        this.properties = properties;
        SimpleClientHttpRequestFactory requestFactory = new SimpleClientHttpRequestFactory();
        requestFactory.setConnectTimeout(Duration.ofSeconds(5));
        requestFactory.setReadTimeout(Duration.ofSeconds(10));
        this.client = RestClient.builder()
                .baseUrl("https://control.msg91.com/api/v5/widget")
                .requestFactory(requestFactory)
                .build();
    }

    /**
     * Checks [accessToken] and that it was issued for [phoneNumber]. A token works once, so a second sign-in
     * needs a new code.
     *
     * @param phoneNumber E.164, e.g. +919876543210
     */
    public void verify(String accessToken, String phoneNumber) {
        Map<?, ?> response;
        try {
            response = client.post()
                    .uri("/verifyAccessToken")
                    .contentType(MediaType.APPLICATION_JSON)
                    .accept(MediaType.APPLICATION_JSON)
                    .body(Map.of("authkey", properties.authKey(), "access-token", accessToken))
                    .retrieve()
                    .body(Map.class);
        } catch (RestClientException e) {
            log.error("MSG91 access token check failed", e);
            throw new BadRequestException("Could not confirm your code. Please try again.");
        }

        // MSG91 answers 200 even for a bad token or authkey, with type "error"
        Object type = response == null ? null : response.get("type");
        if (!"success".equalsIgnoreCase(String.valueOf(type))) {
            // The message can name the problem (expired, already used, bad authkey) but never holds the number
            log.warn("MSG91 rejected an access token: {} {}", type, response == null ? null : response.get("message"));
            throw new BadRequestException("This code has expired. Request a new one.");
        }

        // On success the message is the number the code went to, country code first without the +
        String verified = String.valueOf(response.get("message")).replaceAll("\\D", "");
        if (!verified.equals(phoneNumber.substring(1))) {
            log.warn("MSG91 access token was for {}, not {}",
                    OtpService.mask(verified), OtpService.mask(phoneNumber));
            throw new BadRequestException("That code was sent to a different number. Request a new one.");
        }
    }
}
