package com.example.gamify.dto;

import java.util.List;

/** A page of a player's posts, newest first, plus how many they have in total. */
public record PlayerPostsResponse(
        long total,
        List<PostResponse> posts
) {}
