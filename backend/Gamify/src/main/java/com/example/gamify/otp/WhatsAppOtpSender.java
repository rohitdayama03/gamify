package com.example.gamify.otp;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * Sends sign-in codes as a WhatsApp authentication template through Meta's Cloud API.
 *
 * <p>The API call is commented out until the token and template are ready. To turn it on: fill in the
 * app.whatsapp.* properties, uncomment the block in {@link #send}, and clear app.otp.fixed-code.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class WhatsAppOtpSender {

    private final WhatsAppProperties properties;

    /** @param phoneNumber E.164, e.g. +919876543210 */
    public void send(String phoneNumber, String code) {
        // RestClient client = RestClient.builder()
        //         .baseUrl("https://graph.facebook.com/" + properties.apiVersion())
        //         .defaultHeader(HttpHeaders.AUTHORIZATION, "Bearer " + properties.accessToken())
        //         .build();
        //
        // // Authentication templates take the code twice: in the body and in the "Copy code" button
        // Map<String, Object> body = Map.of(
        //         "messaging_product", "whatsapp",
        //         "to", phoneNumber.substring(1), // Meta expects the number without the leading +
        //         "type", "template",
        //         "template", Map.of(
        //                 "name", properties.templateName(),
        //                 "language", Map.of("code", properties.languageCode()),
        //                 "components", List.of(
        //                         Map.of("type", "body",
        //                                 "parameters", List.of(Map.of("type", "text", "text", code))),
        //                         Map.of("type", "button", "sub_type", "url", "index", "0",
        //                                 "parameters", List.of(Map.of("type", "text", "text", code))))));
        //
        // try {
        //     client.post()
        //             .uri("/{phoneNumberId}/messages", properties.phoneNumberId())
        //             .contentType(MediaType.APPLICATION_JSON)
        //             .body(body)
        //             .retrieve()
        //             .toBodilessEntity();
        // } catch (RestClientException e) {
        //     log.error("WhatsApp OTP to {} failed", mask(phoneNumber), e);
        //     throw new IllegalStateException("Could not send the code on WhatsApp. Please try again.");
        // }

        log.warn("WhatsApp sending is not connected yet; no code was sent to {}", mask(phoneNumber));
    }

    // Logs keep only the last 4 digits of a phone number
    static String mask(String phoneNumber) {
        return phoneNumber.length() <= 4 ? "****" : "*".repeat(phoneNumber.length() - 4) + phoneNumber.substring(phoneNumber.length() - 4);
    }
}
