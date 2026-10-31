package com.example.gamify.dto;

/**
 * How the app gets the code. With MSG91 the number has only been checked: the app sends the code through
 * the MSG91 widget itself. With SERVER (testing) the code has been issued already.
 *
 * @param expiresInSeconds how long the code works (SERVER)
 * @param remainingToday   more codes the number can request today (SERVER)
 * @param widgetId         MSG91 widget to send the code with (MSG91)
 * @param tokenAuth        MSG91 widget token (MSG91)
 */
public record SendOtpResponse(Provider provider, Long expiresInSeconds, Integer remainingToday, String widgetId, String tokenAuth) {

    public enum Provider { MSG91, SERVER }

    public static SendOtpResponse msg91(String widgetId, String tokenAuth) {
        return new SendOtpResponse(Provider.MSG91, null, null, widgetId, tokenAuth);
    }

    public static SendOtpResponse server(long expiresInSeconds, int remainingToday) {
        return new SendOtpResponse(Provider.SERVER, expiresInSeconds, remainingToday, null, null);
    }
}
