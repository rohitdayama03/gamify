package com.example.gamify.service;

import com.example.gamify.dto.*;
import com.example.gamify.entity.Player;

import java.util.List;

public interface PostService {
    /** Starts a post: signed links to upload its files straight to S3. One post at a time per player. */
    UploadSessionResponse startUpload(String username, CreateUploadsRequest request);
    /** Abandons the post being uploaded, so another can start. */
    void cancelUpload(String username);
    /** Saves the post once its files are uploaded. */
    PostResponse createPost(String username, CreatePostRequest request);
    PostResponse getPost(String username, Long postId);
    PlayerPostsResponse getPlayerPosts(String username, Long playerId, Long beforeId);
    void deletePost(String username, Long postId);

    /** Likes or unlikes the post; doing either twice changes nothing. */
    LikeResponse likePost(String username, Long postId);
    LikeResponse unlikePost(String username, Long postId);

    List<CommentResponse> getComments(String username, Long postId, Long afterId);
    CommentResponse addComment(String username, Long postId, String content, Long parentId);
    void deleteComment(String username, Long commentId);

    /** Deletes a player's posts (with their files), comments and likes before their account is deleted. */
    void removePlayerContent(Player player);
}
