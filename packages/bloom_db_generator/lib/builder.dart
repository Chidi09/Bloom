/// Code generator for Bloom ORM models.
///
/// Generates model metadata, row mapping constructors, field value extractors,
/// and ORM extensions for classes annotated with `@BloomModel`.
///
/// ## Overview
///
/// `bloom_db_generator` provides code generation support for the Bloom ORM.
/// When classes are annotated with `@BloomModel`, this generator produces:
///
/// - **Model Metadata**: A `ModelMeta` instance (`_$ModelNameModelMeta`) describing table name,
///   fields, column names, data kinds, indices, and primary keys.
/// - **ORM Mixin**: A `_$ModelNameMixin` implementing `Model` with `modelMeta`, `fieldValues()`,
///   and `toRow()`.
/// - **ORM Extension**: A `ModelNameOrmExtension` extending the model class with:
///   - `meta()`: Static metadata accessor.
///   - `fieldNames()`: List of field names in declaration order.
///   - `fromRow(DbRow row)`: Type-safe deserialization from a database row.
///   - `objects()`: Returns a `QuerySet<T>` for querying, filtering, and aggregation.
///   - `save(DbExecutor db)`: Executes an `INSERT ... RETURNING *` query and returns the refreshed model.
///   - `update(DbExecutor db)`: Executes an `UPDATE` query matching the model's primary key.
///   - `delete(DbExecutor db)`: Executes a `DELETE` query matching the model's primary key.
///
/// ## Usage
///
/// Annotate your model class with `@BloomModel` and include a `part` directive
/// pointing to the `.g.dart` file:
///
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
///   final int age;
///   final bool isActive;
///
///   User({
///     this.id = 0,
///     required this.name,
///     required this.email,
///     this.age = 0,
///     this.isActive = true,
///   });
/// }
/// ```
///
/// Run `build_runner` to generate the `.g.dart` file:
///
/// ```bash
/// dart run build_runner build
/// ```
///
/// Once generated, use the model with `DbExecutor` and `QuerySet`:
///
/// ```dart
/// // Insert a new record
/// final user = await User(name: 'Alice', email: 'alice@example.com').save(db);
///
/// // Query records
/// final activeUsers = await User.objects()
///     .filter('is_active', true)
///     .orderBy('name')
///     .fetch(db);
///
/// // Update record
/// await user.update(db);
///
/// // Delete record
/// await user.delete(db);
/// ```
library bloom_db_generator;

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'src/model_generator.dart';

export 'src/model_generator.dart';

/// Builder factory for generating Bloom model part files (`.g.dart`).
///
/// Configures a [SharedPartBuilder] wrapping [ModelGenerator] with the
/// `'bloom_model'` part-file identifier. This builder is typically registered
/// in `build.yaml` and executed via `dart run build_runner build`.
///
/// The [options] argument contains configuration passed by `build_runner`
/// from `build.yaml`.
///
/// Example `build.yaml` configuration:
/// ```yaml
/// targets:
///   $default:
///     builders:
///       bloom_db_generator:bloom_model:
///         generate_for:
///           - lib/models/*.dart
/// ```
Builder bloomModelBuilder(BuilderOptions options) =>
    SharedPartBuilder([ModelGenerator()], 'bloom_model');

