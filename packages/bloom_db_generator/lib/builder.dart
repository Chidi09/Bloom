/// Code generator for Bloom ORM models.
///
/// Generates model metadata, row mapping constructors, field value extractors,
/// and ORM extensions for classes annotated with `@BloomModel`.
///
/// Example:
/// ```dart
/// import 'package:bloom_db/bloom_db.dart';
///
/// part 'user.g.dart';
///
/// @BloomModel(app: 'auth', tableName: 'auth_users')
/// class User with _$UserMixin {
///   final int id;
///   final String name;
///   final String email;
///
///   User({this.id = 0, required this.name, required this.email});
/// }
/// ```
library bloom_db_generator;

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'src/model_generator.dart';

export 'src/model_generator.dart';

/// Builder factory for generating Bloom model part files (`.g.dart`).
Builder bloomModelBuilder(BuilderOptions options) =>
    SharedPartBuilder([ModelGenerator()], 'bloom_model');

