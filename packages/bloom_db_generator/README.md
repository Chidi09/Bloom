# bloom_db_generator

`build_runner` code generator for [`bloom_db`](https://pub.dev/packages/bloom_db) models. Generates
`ModelMeta`, `fieldValues()`, and row-mapping boilerplate for classes annotated with `@BloomModel`,
so you don't have to hand-write the `ModelMeta`/`fromRow`/`fieldValues` triple yourself.

## Usage

Add both `bloom_db` and `bloom_db_generator` to your `pubspec.yaml`:

```yaml
dependencies:
  bloom_db: ^0.1.0

dev_dependencies:
  build_runner: ^2.4.9
  bloom_db_generator: ^0.1.0
```

Annotate your model and add a `part` directive:

```dart
import 'package:bloom_db/bloom_db.dart';

part 'user.g.dart';

@BloomModel(app: 'auth', tableName: 'auth_users')
class User with _$UserMixin {
  final int id;
  final String name;
  final String email;

  User({this.id = 0, required this.name, required this.email});
}
```

Then run:

```
dart run build_runner build
```

## Part of Bloom Server

`bloom_db_generator` is a dev-time tool for **Bloom Server**, the backend stack for the
[Bloom framework](https://bloom.dev). Scaffold a full project with `bloom server create <name>`
(from `bloom_cli`), or see `examples/bloom_fullstack_todo` in the
[Bloom monorepo](https://github.com/bloom-framework/bloom) for models declared the manual
`ModelMeta` way (no codegen step) if you'd rather skip `build_runner` entirely.

## License

MIT
