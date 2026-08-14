// lib/controllers/feed_controller.dart
import 'package:bloom_framework/bloom.dart';
import '../models/post.dart';

class FeedController extends BloomController {
  final _posts = signal<List<Post>>([]);
  final _isLoading = signal<bool>(false);

  ReadonlySignal<List<Post>> get posts => _posts.readonly();
  ReadonlySignal<bool> get isLoading => _isLoading.readonly();

  static const _demoUser = UserProfile(
    id: 'usr_bloom_dev',
    username: 'bloom_dev',
    displayName: 'Bloom Developer',
    avatarUrl: 'https://images.bloom.dev/avatars/dev.webp',
  );

  static final List<Post> _seedPosts = [
    Post(
      id: 'post_1',
      author: const UserProfile(
        id: 'usr_sol',
        username: 'sol_architect',
        displayName: 'Sol',
        avatarUrl: 'https://images.bloom.dev/avatars/sol.webp',
      ),
      content: 'Bloom 1.0 is here! Signals state management feels exceptionally fast and lightweight. 🚀',
      createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      likesCount: 24,
    ),
    Post(
      id: 'post_2',
      author: const UserProfile(
        id: 'usr_chidi',
        username: 'chidi_mobile',
        displayName: 'Chidi',
        avatarUrl: 'https://images.bloom.dev/avatars/chidi.webp',
      ),
      content: 'Just tested the Bloom Dev Launcher over LAN UDP broadcast. Zero-config wireless device pairing in seconds!',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      likesCount: 18,
    ),
  ];

  @override
  void onInit() {
    super.onInit();
    loadInitialFeed();
  }

  void loadInitialFeed() {
    _posts.value = List.of(_seedPosts);
  }

  void likePost(String postId) {
    final current = List<Post>.from(_posts.value);
    final index = current.indexWhere((p) => p.id == postId);
    if (index != -1) {
      final post = current[index];
      final newLiked = !post.isLiked;
      final newCount = newLiked ? post.likesCount + 1 : post.likesCount - 1;
      current[index] = post.copyWith(isLiked: newLiked, likesCount: newCount);
      _posts.value = current;

      // Add observability breadcrumb
      BloomObservability.addBreadcrumb(
        category: 'social',
        message: 'Toggled like on post $postId (Liked: $newLiked)',
      );
    }
  }

  void addPost(String content, {String? imageUrl}) {
    final newPost = Post(
      id: 'post_${DateTime.now().millisecondsSinceEpoch}',
      author: _demoUser,
      content: content,
      imageUrl: imageUrl,
      createdAt: DateTime.now(),
      likesCount: 0,
      isLiked: false,
    );

    _posts.value = [newPost, ..._posts.value];

    BloomObservability.addBreadcrumb(
      category: 'social',
      message: 'Created new post: ${newPost.id}',
    );
  }
}
