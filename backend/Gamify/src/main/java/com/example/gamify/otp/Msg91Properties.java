package com.example.gamify.otp;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * MSG91 OTP Widget settings (app.msg91.*). The app sends and checks the code with MSG91 itself; the server
 * only confirms the access token MSG91 gives the app afterwards.
 *
 * @param widgetId  id of the OTP widget, from the MSG91 OTP Widget panel
 * @param tokenAuth widget token the app calls MSG91 with (Tokens tab, with Mobile Integration on). It is
 *                  handed to the app, so it is not a secret
 * @param authKey   account authkey the server confirms access tokens with. Secret
 */
@ConfigurationProperties(prefix = "app.msg91")
public record Msg91Properties(String widgetId, String tokenAuth, String authKey) {

    /** Off until all three are set; sign-in then falls back to app.otp.fixed-code. */
    public boolean enabled() {
        return isSet(widgetId) && isSet(tokenAuth) && isSet(authKey);
    }

    private static boolean isSet(String value) {
        return value != null && !value.isBlank();
    }
}
