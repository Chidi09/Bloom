// lib/models/post.dart

class UserProfile {
  final String id;
  final String username;
  final String displayName;
  final String avatarUrl;

  const UserProfile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
  });
}

class Post {
  final String id;
  final UserProfile author;
  final String content;
  final String? imageUrl;
  final DateTime createdAt;
  final int likesCount;
  final bool isLiked;

  const Post({
    required this.id,
    required this.author,
    required this.content,
    this.imageUrl,
    required this.createdAt,
    this.likesCount = 0,
    this.isLiked = false,
  });

  Post copyWith({
    int? likesCount,
    bool? isLiked,
  }) =>
      Post(
        id: id,
        author: author,
        content: content,
        imageUrl: imageUrl,
        createdAt: createdAt,
        likesCount: likesCount ?? this.likesCount,
        isLiked: isLiked ?? this.isLiked,
      );
}
