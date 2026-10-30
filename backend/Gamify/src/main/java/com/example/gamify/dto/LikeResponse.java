package com.example.gamify.dto;

/** Whether the signed-in player now likes the post, and its like count afterwards. */
public record LikeResponse(boolean liked, long likeCount) {}
