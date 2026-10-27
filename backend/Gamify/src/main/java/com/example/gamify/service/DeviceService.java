package com.example.gamify.service;

public interface DeviceService {

    /** Links this phone's push token to the player, moving it from any previous account on the same phone. */
    void register(String username, String token, String platform);

    /** Stops push notifications to this phone for the player (e.g. on logout). */
    void unregister(String username, String token);
}
