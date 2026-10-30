package com.example.gamify.controller;

import com.example.gamify.dto.*;
import com.example.gamify.service.PostService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class PostController {

    private final PostService postService;

    // Step 1: signed links to upload the post's files (the image or video, and a video's thumbnail) straight
    // to S3. Refused while the player is already posting something
    @PostMapping("/posts/uploads")
    public ResponseEntity<UploadSessionResponse> startUpload(
            @AuthenticationPrincipal String currentUsername,
            @Valid @RequestBody CreateUploadsRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(postService.startUpload(currentUsername, request));
    }

    // Gives up on the post being uploaded (e.g. an upload failed), deleting its files, so a new one can start
    @DeleteMapping("/posts/uploads")
    public ResponseEntity<Void> cancelUpload(@AuthenticationPrincipal String currentUsername) {
        postService.cancelUpload(currentUsername);
        return ResponseEntity.noContent().build();
    }

    // Step 2, after the app has uploaded to S3: check the files and save the post
    @PostMapping("/posts")
    public ResponseEntity<PostResponse> createPost(
            @AuthenticationPrincipal String currentUsername,
            @Valid @RequestBody CreatePostRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(postService.createPost(currentUsername, request));
    }

    @GetMapping("/posts/{postId}")
    public ResponseEntity<PostResponse> getPost(
            @AuthenticationPrincipal String currentUsername,
            @PathVariable Long postId) {
        return ResponseEntity.ok(postService.getPost(currentUsername, postId));
    }

    // Author only
    @DeleteMapping("/posts/{postId}")
    public ResponseEntity<Void> deletePost(
            @AuthenticationPrincipal String currentUsername,
            @PathVariable Long postId) {
        postService.deletePost(currentUsername, postId);
        return ResponseEntity.noContent().build();
    }

    // Liking twice, or unliking a post you don't like, is fine: both return where things now stand
    @PutMapping("/posts/{postId}/like")
    public ResponseEntity<LikeResponse> likePost(
            @AuthenticationPrincipal String currentUsername,
            @PathVariable Long postId) {
        return ResponseEntity.ok(postService.likePost(currentUsername, postId));
    }

    @DeleteMapping("/posts/{postId}/like")
    public ResponseEntity<LikeResponse> unlikePost(
            @AuthenticationPrincipal String currentUsername,
            @PathVariable Long postId) {
        return ResponseEntity.ok(postService.unlikePost(currentUsername, postId));
    }

    // A player's posts, newest first; pass beforeId (the last post's id) for the next page
    @GetMapping("/players/{playerId}/posts")
    public ResponseEntity<PlayerPostsResponse> getPlayerPosts(
            @AuthenticationPrincipal String currentUsername,
            @PathVariable Long playerId,
            @RequestParam(required = false) Long beforeId) {
        return ResponseEntity.ok(postService.getPlayerPosts(currentUsername, playerId, beforeId));
    }

    // Top-level comments oldest first, each with its replies; pass afterId (the last comment's id) for the next page
    @GetMapping("/posts/{postId}/comments")
    public ResponseEntity<List<CommentResponse>> getComments(
            @AuthenticationPrincipal String currentUsername,
            @PathVariable Long postId,
            @RequestParam(required = false) Long afterId) {
        return ResponseEntity.ok(postService.getComments(currentUsername, postId, afterId));
    }

    // Comment, or reply when parentId is set
    @PostMapping("/posts/{postId}/comments")
    public ResponseEntity<CommentResponse> addComment(
            @AuthenticationPrincipal String currentUsername,
            @PathVariable Long postId,
            @Valid @RequestBody CreateCommentRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(postService.addComment(currentUsername, postId, request.content(), request.parentId()));
    }

    // The comment's author or the post's author
    @DeleteMapping("/comments/{commentId}")
    public ResponseEntity<Void> deleteComment(
            @AuthenticationPrincipal String currentUsername,
            @PathVariable Long commentId) {
        postService.deleteComment(currentUsername, commentId);
        return ResponseEntity.noContent().build();
    }
}
