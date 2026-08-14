// test/feed_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bloom_social_feed/controllers/feed_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bloom Social: FeedController Signals & Likes', () {
    late FeedController feed;

    setUp(() {
      feed = FeedController();
      feed.onInit();
    });

    test('Initializes feed with seed posts', () {
      expect(feed.posts.value.length, greaterThanOrEqualTo(2));
      expect(feed.posts.value.first.author.username, 'sol_architect');
    });

    test('Liking post toggles liked status and increments/decrements like counter optimistically', () {
      final initialPost = feed.posts.value.first;
      final initialLikes = initialPost.likesCount;
      final id = initialPost.id;

      // Like
      feed.likePost(id);
      final updatedPost = feed.posts.value.firstWhere((p) => p.id == id);
      expect(updatedPost.isLiked, isTrue);
      expect(updatedPost.likesCount, initialLikes + 1);

      // Unlike
      feed.likePost(id);
      final unlikedPost = feed.posts.value.firstWhere((p) => p.id == id);
      expect(unlikedPost.isLiked, isFalse);
      expect(unlikedPost.likesCount, initialLikes);
    });

    test('Adding a new post prepends it to the feed list', () {
      final initialCount = feed.posts.value.length;
      feed.addPost('Testing Bloom social feed additions!');

      expect(feed.posts.value.length, initialCount + 1);
      expect(feed.posts.value.first.content, 'Testing Bloom social feed additions!');
      expect(feed.posts.value.first.author.username, 'bloom_dev');
    });
  });
}
