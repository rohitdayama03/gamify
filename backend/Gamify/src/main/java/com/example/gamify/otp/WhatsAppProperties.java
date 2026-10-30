package com.example.gamify.otp;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Meta WhatsApp Cloud API settings (app.whatsapp.*).
 *
 * @param accessToken   permanent token of the WhatsApp Business system user
 * @param phoneNumberId id of the sending business number (not the number itself), from the WhatsApp Manager
 * @param templateName  approved "Authentication" template that carries the code
 * @param languageCode  language the template was approved in, e.g. en or en_US
 * @param apiVersion    Graph API version, e.g. v21.0
 */
@ConfigurationProperties(prefix = "app.whatsapp")
public record WhatsAppProperties(
        String accessToken,
        String phoneNumberId,
        String templateName,
        String languageCode,
        String apiVersion
) {}
