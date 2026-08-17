// test/models/user.dart
import 'package:bloom_db/bloom_db.dart';

part 'user.g.dart';

@BloomModel(app: 'auth', tableName: 'auth_users')
class User with _$UserMixin {
  final int id;
  final String name;
  final String email;
  final int age;
  final bool isActive;

  User({
    this.id = 0,
    required this.name,
    required this.email,
    this.age = 0,
    this.isActive = true,
  });

  @override
  String toString() => 'User(id: $id, name: $name, email: $email, age: $age, isActive: $isActive)';
}
