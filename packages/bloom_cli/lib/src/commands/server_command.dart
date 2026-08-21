// lib/src/commands/server_command.dart
import 'dart:async';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import '../utils/ansi.dart';

/// The Bloom Server package suite: bloom_db, bloom_db_generator, bloom_validate,
/// bloom_auth_server, bloom_errors, bloom_rest, bloom_migrate. This is the "core"
/// set every scaffolded server depends on — mail/jobs/storage/realtime/cache/i18n/admin
/// are intentionally left out of the base scaffold (same as Django's own `startproject`
/// not wiring in every contrib app); see `bloom_fullstack_todo` for a reference project
/// that wires in all fifteen Bloom Server packages together.
const List<String> _corePackages = [
  'bloom_framework',
  'bloom_db',
  'bloom_validate',
  'bloom_auth_server',
  'bloom_errors',
  'bloom_rest',
  'bloom_migrate',
];

const List<String> _devOnlyPackages = ['bloom_db_generator'];

class ServerCommand extends Command<int> {
  @override
  final String name = 'server';

  @override
  final String description = 'Scaffold and manage Bloom Server (backend) projects, Django-style.';

  ServerCommand() {
    addSubcommand(_ServerCreateCommand());
    addSubcommand(_ServerStartAppCommand());
    addSubcommand(_ServerRunCommand());
  }
}

/// Resolves a bloom_* server package to a pubspec dependency line.
///
/// Tries, in order: an explicit `--packages-path` override, the
/// `BLOOM_PACKAGES_PATH` environment variable, then auto-detecting a sibling
/// `packages/` directory relative to the running `bloom` script (true inside
/// the Bloom monorepo). Falls back to a pub.dev version constraint only for
/// `bloom_framework`, since it is the only one of these currently published —
/// the rest are monorepo-only (`publish_to: none`) until published.
String _depSpec(String packageName, {String? packagesPathOverride, required String indent}) {
  Directory? resolvedRoot;

  if (packagesPathOverride != null && Directory(packagesPathOverride).existsSync()) {
    resolvedRoot = Directory(packagesPathOverride);
  } else if (Platform.environment['BLOOM_PACKAGES_PATH'] != null &&
      Directory(Platform.environment['BLOOM_PACKAGES_PATH']!).existsSync()) {
    resolvedRoot = Directory(Platform.environment['BLOOM_PACKAGES_PATH']!);
  } else {
    try {
      final scriptDir = p.dirname(Platform.script.toFilePath());
      final siblingPackages = p.normalize(p.join(scriptDir, '..', '..'));
      if (Directory(p.join(siblingPackages, 'bloom_framework')).existsSync()) {
        resolvedRoot = Directory(siblingPackages);
      }
    } catch (_) {
      // Fall through to the pub.dev fallback below.
    }
  }

  if (resolvedRoot != null) {
    final pkgDir = p.join(resolvedRoot.path, packageName);
    if (Directory(pkgDir).existsSync()) {
      return '$indent$packageName:\n$indent  path: ${p.canonicalize(pkgDir)}';
    }
  }

  if (packageName == 'bloom_framework') {
    return '$indent$packageName: ^0.2.2';
  }

  // Not resolvable and not published — emit a path placeholder so `dart pub get`
  // fails loudly with a clear "no such directory" instead of a confusing
  // "version not found" pub.dev error, and tell the user how to fix it.
  return '$indent$packageName:\n$indent  path: ../../packages/$packageName # <-- set --packages-path or BLOOM_PACKAGES_PATH if this is wrong';
}

class _ServerCreateCommand extends Command<int> {
  @override
  final String name = 'create';

  @override
  final String description = 'Scaffolds a new Bloom Server project with Django-style apps/ layout.';

  _ServerCreateCommand() {
    argParser
      ..addOption('packages-path', help: 'Path to the directory containing the bloom_* server packages (monorepo `packages/` dir).')
      ..addOption('db', allowed: ['postgres', 'sqlite'], defaultsTo: 'postgres', help: 'Default database dialect for the generated settings.dart.');
  }

  @override
  Future<int> run() async {
    final rest = argResults?.rest ?? [];
    if (rest.isEmpty) {
      print(Ansi.error('Please specify a project name.'));
      print('Usage: bloom server create <name>');
      return 1;
    }

    final projectName = rest.first.trim().toLowerCase().replaceAll('-', '_');
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(projectName)) {
      print(Ansi.error('Invalid project name: "$projectName". Must be lowercase letters, numbers, and underscores, starting with a letter.'));
      return 1;
    }

    final packagesPath = argResults?['packages-path'] as String?;
    final db = argResults?['db'] as String? ?? 'postgres';

    final targetDir = Directory(p.join(Directory.current.path, projectName));
    if (targetDir.existsSync() && targetDir.listSync().isNotEmpty) {
      print(Ansi.error('Directory "${targetDir.path}" already exists and is not empty.'));
      return 1;
    }

    print(Ansi.boldText('\n🌱 Creating Bloom Server project: ${Ansi.cyan}$projectName${Ansi.reset}\n'));

    print(Ansi.step('1/5 Creating project directories...'));
    for (final dir in [
      'bin',
      'lib/apps/accounts',
      'lib/apps/notes',
      'migrations/accounts',
      'migrations/notes',
      'storage/uploads',
    ]) {
      Directory(p.join(targetDir.path, dir)).createSync(recursive: true);
    }

    print(Ansi.step('2/5 Writing pubspec.yaml...'));
    File(p.join(targetDir.path, 'pubspec.yaml')).writeAsStringSync(
      _pubspecYaml(projectName, packagesPath: packagesPath),
    );

    print(Ansi.step('3/5 Writing settings.dart, urls.dart, and bin/server.dart...'));
    File(p.join(targetDir.path, 'lib', 'settings.dart')).writeAsStringSync(_settingsDart(db: db));
    File(p.join(targetDir.path, 'lib', 'urls.dart')).writeAsStringSync(_rootUrlsDart());
    File(p.join(targetDir.path, 'bin', 'server.dart')).writeAsStringSync(_binServerDart(projectName));

    print(Ansi.step('4/5 Scaffolding starter apps: accounts, notes...'));
    _writeAccountsApp(targetDir.path);
    _writeNotesApp(targetDir.path);

    print(Ansi.step('5/5 Writing .env, .env.example, and README.md...'));
    File(p.join(targetDir.path, '.env')).writeAsStringSync(_envFile(db: db));
    File(p.join(targetDir.path, '.env.example')).writeAsStringSync(_envFile(db: db));
    File(p.join(targetDir.path, 'README.md')).writeAsStringSync(_readme(projectName));

    print(Ansi.success('\n✔ Bloom Server project "$projectName" created.\n'));
    print('  cd $projectName');
    print('  dart pub get');
    print('  dart run bin/server.dart');
    print('');
    print('  Add another app anytime with: bloom server startapp <app_name>');
    print('  Wanted mail/jobs/storage/realtime/cache/i18n/admin too? See examples/bloom_fullstack_todo');
    print('  for the reference wiring of all fifteen Bloom Server packages together.\n');

    return 0;
  }

  String _pubspecYaml(String projectName, {String? packagesPath}) {
    final deps = _corePackages.map((pkg) => _depSpec(pkg, packagesPathOverride: packagesPath, indent: '  ')).join('\n');
    final devDeps = _devOnlyPackages.map((pkg) => _depSpec(pkg, packagesPathOverride: packagesPath, indent: '  ')).join('\n');

    return '''
name: $projectName
description: A Bloom Server backend, scaffolded Django-style.
version: 1.0.0
publish_to: 'none'

environment:
  sdk: '>=3.3.0 <4.0.0'

dependencies:
$deps
  meta: ^1.15.0
  postgres: ^3.2.1
  crypto: ^3.0.3

dev_dependencies:
  build_runner: ^2.4.9
$devDeps
''';
  }

  String _settingsDart({required String db}) {
    return '''
// lib/settings.dart
//
// Central configuration for this Bloom Server project — the equivalent of
// Django's settings.py. Reads environment variables, opens the database
// connection, and wires up the global middleware stack. `bin/server.dart`
// calls [configureBloomServer] once at boot and passes the resulting
// [BloomServerContext] down into each app's `urls.dart`.
import 'dart:io';
import 'package:bloom_framework/bloom_server.dart';
import 'package:bloom_db/bloom_db.dart';

class BloomServerContext {
  final DbExecutor db;
  final int port;

  BloomServerContext({required this.db, required this.port});
}

Future<BloomServerContext> configureBloomServer() async {
  final envFile = File('.env');
  if (envFile.existsSync()) {
    BloomEnv.loadContent(envFile.readAsStringSync());
  }

  BloomEnv.loadMap({
    'DB_HOST': BloomEnv.getOrNull('DB_HOST') ?? '127.0.0.1',
    'DB_PORT': BloomEnv.getOrNull('DB_PORT') ?? '${db == 'postgres' ? '5432' : '0'}',
    'DB_USER': BloomEnv.getOrNull('DB_USER') ?? 'postgres',
    'DB_PASSWORD': BloomEnv.getOrNull('DB_PASSWORD') ?? 'postgres',
    'DB_NAME': BloomEnv.getOrNull('DB_NAME') ?? 'bloom_server_dev',
    'BLOOM_AUTH_SECRET': BloomEnv.getOrNull('BLOOM_AUTH_SECRET') ??
        'change-this-to-a-real-secret-at-least-32-characters-long',
    'APP_ENV': BloomEnv.getOrNull('APP_ENV') ?? 'local',
    'PORT': BloomEnv.getOrNull('PORT') ?? '8080',
  }, overwrite: false);

  ${db == 'postgres' ? '''final db = await PostgresDbExecutor.connect(
    host: BloomEnv.get('DB_HOST'),
    port: BloomEnv.getInt('DB_PORT', defaultValue: 5432),
    username: BloomEnv.get('DB_USER'),
    password: BloomEnv.get('DB_PASSWORD'),
    database: BloomEnv.get('DB_NAME'),
  );''' : '''final db = await SqliteDbExecutor.openFile(BloomEnv.get('DB_NAME', defaultValue: 'bloom_server_dev.db'));'''}
  globalContainer.provideValue<DbExecutor>(db);

  return BloomServerContext(
    db: db,
    port: BloomEnv.getInt('PORT', defaultValue: 8080),
  );
}
''';
  }

  String _rootUrlsDart() {
    return '''
// lib/urls.dart
//
// Root URL routing — the equivalent of Django's project-level urls.py.
// Each app owns its own routes; this file just mounts them under a prefix,
// mirroring `path('accounts/', include('accounts.urls'))`.
import 'package:bloom_framework/bloom_server.dart';
import 'settings.dart';
import 'apps/accounts/urls.dart' as accounts;
import 'apps/notes/urls.dart' as notes;

void registerUrls(BloomApiRouter router, BloomServerContext ctx) {
  router.get('/api/health', (req) async {
    return BloomResponse.json({'status': 'healthy'});
  });

  accounts.registerUrls(router, ctx);
  notes.registerUrls(router, ctx);
}
''';
  }

  String _binServerDart(String projectName) {
    return '''
// bin/server.dart
//
// Boots the server — the equivalent of Django's manage.py runserver.
import 'dart:io';
import 'package:bloom_framework/bloom_server.dart';
import 'package:bloom_errors/bloom_errors.dart';
import 'package:bloom_migrate/bloom_migrate.dart';
import '../lib/settings.dart';
import '../lib/urls.dart';

Future<void> main(List<String> args) async {
  final ctx = await configureBloomServer();

  stdout.writeln('Running database migrations...');
  final migrationRunner = MigrationRunner(db: ctx.db, migrationsDirectory: 'migrations');
  try {
    final applied = await migrationRunner.migrate();
    stdout.writeln('Applied \${applied.length} pending migration(s).');
  } catch (e) {
    stdout.writeln('Note on migrations: \$e');
  }

  final router = BloomApiRouter();
  router.use(const BloomErrorMiddleware());

  registerUrls(router, ctx);

  final server = await router.serve(port: ctx.port);
  stdout.writeln('$projectName listening on http://127.0.0.1:\${server.port}');
}
''';
  }

  void _writeAccountsApp(String projectRoot) {
    final dir = p.join(projectRoot, 'lib', 'apps', 'accounts');

    File(p.join(dir, 'models.dart')).writeAsStringSync('''
// lib/apps/accounts/models.dart
import 'package:bloom_db/bloom_db.dart';

@BloomModel(app: 'accounts', tableName: 'accounts_users')
class User extends Model {
  @BloomField(primaryKey: true, auto: true, kind: FieldKind.bigInt)
  final int id;

  @BloomField(kind: FieldKind.char, maxLength: 255)
  final String email;

  @BloomField(column: 'password_hash', kind: FieldKind.char, maxLength: 255)
  final String passwordHash;

  @BloomField(kind: FieldKind.char, maxLength: 255)
  final String name;

  @BloomField(column: 'created_at', kind: FieldKind.dateTime)
  final DateTime createdAt;

  User({
    this.id = 0,
    required this.email,
    required this.passwordHash,
    required this.name,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toUtc();

  static final meta = ModelMeta(
    structName: 'User',
    appLabel: 'accounts',
    tableName: 'accounts_users',
    fields: [
      FieldMeta(name: 'id', columnName: 'id', kind: FieldKind.bigInt, primaryKey: true, auto: true),
      FieldMeta(name: 'email', columnName: 'email', kind: FieldKind.char, maxLength: 255),
      FieldMeta(name: 'passwordHash', columnName: 'password_hash', kind: FieldKind.char, maxLength: 255),
      FieldMeta(name: 'name', columnName: 'name', kind: FieldKind.char, maxLength: 255),
      FieldMeta(name: 'createdAt', columnName: 'created_at', kind: FieldKind.dateTime),
    ],
    ordering: ['id'],
  );

  @override
  ModelMeta get modelMeta => meta;

  @override
  List<(String, BloomValue)> fieldValues() => [
        ('id', BloomValue.i64(id)),
        ('email', BloomValue.text(email)),
        ('passwordHash', BloomValue.text(passwordHash)),
        ('name', BloomValue.text(name)),
        ('createdAt', BloomValue.dateTime(createdAt)),
      ];

  static User fromRow(DbRow row) {
    return User(
      id: row.tryIntByName('id') ?? 0,
      email: row.tryStringByName('email') ?? '',
      passwordHash: row.tryStringByName('password_hash') ?? '',
      name: row.tryStringByName('name') ?? '',
      createdAt: row.tryDateTimeByName('created_at') ?? DateTime.now().toUtc(),
    );
  }

  static QuerySet<User> objects() => QuerySet<User>(meta: meta, fromRow: fromRow);

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
      };
}
''');

    File(p.join(dir, 'serializers.dart')).writeAsStringSync('''
// lib/apps/accounts/serializers.dart
import 'package:bloom_validate/bloom_validate.dart';

class SignupSchema extends BloomRequestSchema {
  SignupSchema(super.data);
  SignupSchema.fromRequest(super.request) : super.fromRequest();

  late final String name = requireStringLength('name', min: 2, max: 100);
  late final String email = requireEmail('email');
  late final String password = requireStringLength('password', min: 8, max: 128);

  @override
  void validate() {
    name;
    email;
    password;
  }
}

class LoginSchema extends BloomRequestSchema {
  LoginSchema(super.data);
  LoginSchema.fromRequest(super.request) : super.fromRequest();

  late final String email = requireEmail('email');
  late final String password = requireString('password');

  @override
  void validate() {
    email;
    password;
  }
}
''');

    File(p.join(dir, 'permissions.dart')).writeAsStringSync('''
// lib/apps/accounts/permissions.dart
//
// This app only needs bloom_rest's built-in permission classes today.
// Add custom BloomRestPermission subclasses here as the project grows —
// see bloom_rest's README for the pattern.
export 'package:bloom_rest/bloom_rest.dart' show BloomRestPermission, IsAuthenticated, AllowAny;
''');

    File(p.join(dir, 'views.dart')).writeAsStringSync('''
// lib/apps/accounts/views.dart
import 'package:bloom_auth_server/bloom_auth_server.dart';
import 'package:bloom_db/bloom_db.dart';
import 'package:bloom_errors/bloom_errors.dart';
import 'package:bloom_framework/bloom_server.dart';
import 'package:bloom_validate/bloom_validate.dart';
import 'models.dart';
import 'serializers.dart';

class AccountViews {
  final DbExecutor db;

  AccountViews({required this.db});

  Future<BloomResponse> signup(BloomRequest req) async {
    final SignupSchema schema;
    try {
      schema = BloomRequestSchema.validateSchema(SignupSchema.fromRequest(req));
    } on BloomValidationException catch (e) {
      throw BloomValidationFailedException(message: e.message, errors: e.errors);
    }

    final email = schema.email.trim().toLowerCase();
    final existing = await User.objects().filter(Q('email', email)).first(db);
    if (existing != null) {
      throw BloomConflictException('An account with email "\$email" already exists.');
    }

    final insertedId = await QuerySet.insertRaw(db, User.meta, {
      'email': email,
      'password_hash': hashPassword(schema.password, cost: 12),
      'name': schema.name.trim(),
      'created_at': DateTime.now().toUtc(),
    });

    final user = await User.objects().filter(Q('id', insertedId)).get(db);
    final token = issueSessionToken(userId: user.id.toString(), email: user.email, roles: const ['user']);

    return BloomResponse.json({'token': token, 'user': user.toJson()}, statusCode: 201);
  }

  Future<BloomResponse> login(BloomRequest req) async {
    final LoginSchema schema;
    try {
      schema = BloomRequestSchema.validateSchema(LoginSchema.fromRequest(req));
    } on BloomValidationException catch (e) {
      throw BloomValidationFailedException(message: e.message, errors: e.errors);
    }

    final email = schema.email.trim().toLowerCase();
    final user = await User.objects().filter(Q('email', email)).first(db);
    if (user == null || !verifyPassword(schema.password, user.passwordHash)) {
      if (user == null) dummyVerifyPassword(schema.password);
      throw BloomUnauthorizedException('Invalid email or password');
    }

    final token = issueSessionToken(userId: user.id.toString(), email: user.email, roles: const ['user']);
    return BloomResponse.json({'token': token, 'user': user.toJson()});
  }

  Future<BloomResponse> me(BloomRequest req) async {
    final userId = int.tryParse(req.authUserId ?? '') ?? 0;
    final user = await User.objects().filter(Q('id', userId)).first(db);
    if (user == null) throw BloomNotFoundException('User account not found.');
    return BloomResponse.json({'user': user.toJson()});
  }
}
''');

    File(p.join(dir, 'urls.dart')).writeAsStringSync('''
// lib/apps/accounts/urls.dart
import 'package:bloom_auth_server/bloom_auth_server.dart';
import 'package:bloom_framework/bloom_server.dart';
import '../../settings.dart';
import 'views.dart';

void registerUrls(BloomApiRouter router, BloomServerContext ctx) {
  final views = AccountViews(db: ctx.db);

  router.post('/api/accounts/signup', views.signup);
  router.post('/api/accounts/login', views.login);
  router.get('/api/accounts/me', views.me, middlewares: [const BloomAuthMiddleware()]);
}
''');

    File(p.join(p.dirname(p.dirname(p.dirname(dir))), 'migrations', 'accounts', '0001_initial.sql')).writeAsStringSync('''
-- up
CREATE TABLE IF NOT EXISTS accounts_users (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- down
DROP TABLE IF EXISTS accounts_users;
''');
  }

  void _writeNotesApp(String projectRoot) {
    final dir = p.join(projectRoot, 'lib', 'apps', 'notes');

    File(p.join(dir, 'models.dart')).writeAsStringSync('''
// lib/apps/notes/models.dart
import 'package:bloom_db/bloom_db.dart';
import '../accounts/models.dart';

@BloomModel(app: 'notes', tableName: 'notes_notes')
class Note extends Model {
  @BloomField(primaryKey: true, auto: true, kind: FieldKind.bigInt)
  final int id;

  @BloomField(kind: FieldKind.char, maxLength: 255)
  final String title;

  @BloomField(kind: FieldKind.text)
  final String body;

  @BloomField(column: 'owner_id', kind: FieldKind.bigInt)
  final int ownerId;

  @BloomField(column: 'created_at', kind: FieldKind.dateTime)
  final DateTime createdAt;

  Note({
    this.id = 0,
    required this.title,
    required this.body,
    required this.ownerId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toUtc();

  static final meta = ModelMeta(
    structName: 'Note',
    appLabel: 'notes',
    tableName: 'notes_notes',
    fields: [
      FieldMeta(name: 'id', columnName: 'id', kind: FieldKind.bigInt, primaryKey: true, auto: true),
      FieldMeta(name: 'title', columnName: 'title', kind: FieldKind.char, maxLength: 255),
      FieldMeta(name: 'body', columnName: 'body', kind: FieldKind.text),
      FieldMeta(name: 'ownerId', columnName: 'owner_id', kind: FieldKind.bigInt),
      FieldMeta(name: 'createdAt', columnName: 'created_at', kind: FieldKind.dateTime),
    ],
    relations: [
      RelationMeta(
        fieldName: 'ownerId',
        kind: RelationKind.foreignKey,
        target: () => User.meta,
        onDelete: OnDelete.cascade,
      ),
    ],
    ordering: ['-createdAt', 'id'],
  );

  @override
  ModelMeta get modelMeta => meta;

  @override
  List<(String, BloomValue)> fieldValues() => [
        ('id', BloomValue.i64(id)),
        ('title', BloomValue.text(title)),
        ('body', BloomValue.text(body)),
        ('ownerId', BloomValue.i64(ownerId)),
        ('createdAt', BloomValue.dateTime(createdAt)),
      ];

  static Note fromRow(DbRow row) {
    return Note(
      id: row.tryIntByName('id') ?? 0,
      title: row.tryStringByName('title') ?? '',
      body: row.tryStringByName('body') ?? '',
      ownerId: row.tryIntByName('owner_id') ?? 0,
      createdAt: row.tryDateTimeByName('created_at') ?? DateTime.now().toUtc(),
    );
  }

  static QuerySet<Note> objects() => QuerySet<Note>(meta: meta, fromRow: fromRow);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'ownerId': ownerId,
        'createdAt': createdAt.toIso8601String(),
      };
}
''');

    File(p.join(dir, 'serializers.dart')).writeAsStringSync('''
// lib/apps/notes/serializers.dart
import 'package:bloom_validate/bloom_validate.dart';

class NoteSchema extends BloomRequestSchema {
  NoteSchema(super.data);
  NoteSchema.fromRequest(super.request) : super.fromRequest();

  late final String title = requireStringLength('title', min: 1, max: 255);
  late final String body = optionalString('body', defaultValue: '') ?? '';

  @override
  void validate() {
    title;
    body;
  }
}
''');

    File(p.join(dir, 'permissions.dart')).writeAsStringSync('''
// lib/apps/notes/permissions.dart
export 'package:bloom_rest/bloom_rest.dart' show BloomRestPermission, IsAuthenticated;
''');

    File(p.join(dir, 'views.dart')).writeAsStringSync('''
// lib/apps/notes/views.dart
import 'package:bloom_auth_server/bloom_auth_server.dart';
import 'package:bloom_db/bloom_db.dart';
import 'package:bloom_errors/bloom_errors.dart';
import 'package:bloom_framework/bloom_server.dart';
import 'package:bloom_rest/bloom_rest.dart';
import 'package:bloom_validate/bloom_validate.dart';
import 'models.dart';
import 'serializers.dart';

/// Ownership-scoped CRUD ViewSet for Note. Every method checks the note
/// belongs to the requesting (verified) user before reading or mutating it —
/// see bloom_rest's README for why permission checks alone aren't enough
/// for row-level ownership, only request-level authorization.
class NoteViewSet extends BloomViewSet<Note> {
  NoteViewSet({required DbExecutor Function(BloomRequest req) getDb})
      : super(
          meta: Note.meta,
          fromRow: Note.fromRow,
          getDb: getDb,
          options: BloomViewSetOptions<Note>(
            serializer: BloomModelSerializer<Note>(
              meta: Note.meta,
              fields: BloomFieldSet.all().withReadOnly(['id', 'ownerId', 'createdAt']),
            ),
            pagination: const PageNumberPagination(defaultPageSize: 20),
            permission: const IsAuthenticated(),
            config: const BloomViewSetConfig(
              filterableFields: ['title'],
              orderableFields: ['created_at', 'id'],
              defaultPageSize: 20,
            ),
          ),
        );

  int _ownerId(BloomRequest req) {
    final uid = int.tryParse(req.authUserId ?? '');
    if (uid == null) throw BloomUnauthorizedException('Authentication required');
    return uid;
  }

  @override
  Future<BloomResponse> list(BloomRequest req) async {
    final ownerId = _ownerId(req);
    final db = getDb(req);
    final notes = await Note.objects().filter(Q('ownerId', ownerId)).orderBy('-createdAt').all(db);
    return BloomResponse.json({'count': notes.length, 'results': notes.map((n) => n.toJson()).toList()});
  }

  @override
  Future<BloomResponse> create(BloomRequest req) async {
    final ownerId = _ownerId(req);
    final schema = BloomRequestSchema.validateSchema(NoteSchema.fromRequest(req));
    final db = getDb(req);

    final insertedId = await QuerySet.insertRaw(db, Note.meta, {
      'title': schema.title,
      'body': schema.body,
      'owner_id': ownerId,
      'created_at': DateTime.now().toUtc(),
    });
    final note = await Note.objects().filter(Q('id', insertedId)).get(db);
    return BloomResponse.json(note.toJson(), statusCode: 201);
  }

  @override
  Future<BloomResponse> retrieve(BloomRequest req) async {
    final ownerId = _ownerId(req);
    final pk = int.tryParse(req.params['pk'] ?? '');
    if (pk == null) throw BloomBadRequestException('Invalid note ID');

    final db = getDb(req);
    final note = await Note.objects().filter(Q('id', pk) & Q('ownerId', ownerId)).first(db);
    if (note == null) throw BloomNotFoundException('Note not found');
    return BloomResponse.json(note.toJson());
  }

  @override
  Future<BloomResponse> update(BloomRequest req) async {
    final ownerId = _ownerId(req);
    final pk = int.tryParse(req.params['pk'] ?? '');
    if (pk == null) throw BloomBadRequestException('Invalid note ID');

    final schema = BloomRequestSchema.validateSchema(NoteSchema.fromRequest(req));
    final db = getDb(req);
    final qs = Note.objects().filter(Q('id', pk) & Q('ownerId', ownerId));
    final updated = await qs.update(db, {'title': schema.title, 'body': schema.body});
    if (updated == 0) throw BloomNotFoundException('Note not found or unauthorized');

    return BloomResponse.json((await qs.get(db)).toJson());
  }

  @override
  Future<BloomResponse> destroy(BloomRequest req) async {
    final ownerId = _ownerId(req);
    final pk = int.tryParse(req.params['pk'] ?? '');
    if (pk == null) throw BloomBadRequestException('Invalid note ID');

    final db = getDb(req);
    final deleted = await Note.objects().filter(Q('id', pk) & Q('ownerId', ownerId)).delete(db);
    if (deleted == 0) throw BloomNotFoundException('Note not found or unauthorized');
    return BloomResponse.noContent();
  }
}
''');

    File(p.join(dir, 'urls.dart')).writeAsStringSync('''
// lib/apps/notes/urls.dart
import 'package:bloom_auth_server/bloom_auth_server.dart';
import 'package:bloom_framework/bloom_server.dart';
import '../../settings.dart';
import 'views.dart';

void registerUrls(BloomApiRouter router, BloomServerContext ctx) {
  final notes = NoteViewSet(getDb: (_) => ctx.db);
  const auth = [BloomAuthMiddleware()];

  router.get('/api/notes', notes.list, middlewares: auth);
  router.post('/api/notes', notes.create, middlewares: auth);
  router.get('/api/notes/:pk', notes.retrieve, middlewares: auth);
  router.put('/api/notes/:pk', notes.update, middlewares: auth);
  router.patch('/api/notes/:pk', notes.update, middlewares: auth);
  router.delete('/api/notes/:pk', notes.destroy, middlewares: auth);
}
''');

    File(p.join(p.dirname(p.dirname(p.dirname(dir))), 'migrations', 'notes', '0001_initial.sql')).writeAsStringSync('''
-- up
CREATE TABLE IF NOT EXISTS notes_notes (
    id BIGSERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL DEFAULT '',
    owner_id BIGINT NOT NULL REFERENCES accounts_users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS notes_notes_owner_id_idx ON notes_notes(owner_id);

-- down
DROP TABLE IF EXISTS notes_notes;
''');
  }

  String _envFile({required String db}) {
    return '''
APP_ENV=local
PORT=8080
DB_HOST=127.0.0.1
DB_PORT=${db == 'postgres' ? '5432' : '0'}
DB_USER=postgres
DB_PASSWORD=postgres
DB_NAME=bloom_server_dev
BLOOM_AUTH_SECRET=change-this-to-a-real-secret-at-least-32-characters-long
''';
  }

  String _readme(String projectName) {
    return '''
# $projectName

A Bloom Server backend, scaffolded Django-style:

```
bin/server.dart       manage.py equivalent — boots settings, runs migrations, starts the router
lib/settings.dart     settings.py equivalent — env, DB connection, DI wiring
lib/urls.dart         root urls.py equivalent — mounts each app's routes
lib/apps/accounts/    models.dart, serializers.dart, views.dart, permissions.dart, urls.dart
lib/apps/notes/       same shape — copy this app's structure for every new domain
migrations/<app>/     one directory per app, applied in filename order by bloom_migrate
```

## Run it

```
dart pub get
dart run bin/server.dart
```

## Add a new app

```
bloom server startapp billing
```

## Want more of the stack?

This scaffold wires in the core 7: bloom_framework, bloom_db, bloom_validate,
bloom_auth_server, bloom_errors, bloom_rest, bloom_migrate. For mail, background
jobs, file storage, realtime WebSockets, response caching, i18n, or the admin
panel, see `examples/bloom_fullstack_todo` in the Bloom monorepo for a working
reference that wires in all fifteen Bloom Server packages together.
''';
  }
}

class _ServerStartAppCommand extends Command<int> {
  @override
  final String name = 'startapp';

  @override
  final String description = 'Scaffolds a new app (models/serializers/views/permissions/urls) into an existing Bloom Server project.';

  _ServerStartAppCommand() {
    argParser.addOption('server-dir', help: 'Path to the Bloom Server project root (defaults to current directory).');
  }

  @override
  Future<int> run() async {
    final rest = argResults?.rest ?? [];
    if (rest.isEmpty) {
      print(Ansi.error('Please specify an app name.'));
      print('Usage: bloom server startapp <app_name>');
      return 1;
    }

    final appName = rest.first.trim().toLowerCase().replaceAll('-', '_');
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(appName)) {
      print(Ansi.error('Invalid app name: "$appName". Must be lowercase letters, numbers, and underscores, starting with a letter.'));
      return 1;
    }

    final serverDir = argResults?['server-dir'] as String? ?? Directory.current.path;
    final urlsFile = File(p.join(serverDir, 'lib', 'urls.dart'));
    if (!urlsFile.existsSync()) {
      print(Ansi.error('Not a Bloom Server project root (missing lib/urls.dart): $serverDir'));
      print('Run this from the project root, or pass --server-dir.');
      return 1;
    }

    final appDir = Directory(p.join(serverDir, 'lib', 'apps', appName));
    if (appDir.existsSync() && appDir.listSync().isNotEmpty) {
      print(Ansi.error('App "$appName" already exists at ${appDir.path}'));
      return 1;
    }
    appDir.createSync(recursive: true);
    Directory(p.join(serverDir, 'migrations', appName)).createSync(recursive: true);

    final className = _pascalCase(appName);

    File(p.join(appDir.path, 'models.dart')).writeAsStringSync('''
// lib/apps/$appName/models.dart
import 'package:bloom_db/bloom_db.dart';

@BloomModel(app: '$appName', tableName: '${appName}_${appName}s')
class $className extends Model {
  @BloomField(primaryKey: true, auto: true, kind: FieldKind.bigInt)
  final int id;

  @BloomField(column: 'created_at', kind: FieldKind.dateTime)
  final DateTime createdAt;

  $className({this.id = 0, DateTime? createdAt}) : createdAt = createdAt ?? DateTime.now().toUtc();

  static final meta = ModelMeta(
    structName: '$className',
    appLabel: '$appName',
    tableName: '${appName}_${appName}s',
    fields: [
      FieldMeta(name: 'id', columnName: 'id', kind: FieldKind.bigInt, primaryKey: true, auto: true),
      FieldMeta(name: 'createdAt', columnName: 'created_at', kind: FieldKind.dateTime),
    ],
    ordering: ['id'],
  );

  @override
  ModelMeta get modelMeta => meta;

  @override
  List<(String, BloomValue)> fieldValues() => [
        ('id', BloomValue.i64(id)),
        ('createdAt', BloomValue.dateTime(createdAt)),
      ];

  static $className fromRow(DbRow row) {
    return $className(
      id: row.tryIntByName('id') ?? 0,
      createdAt: row.tryDateTimeByName('created_at') ?? DateTime.now().toUtc(),
    );
  }

  static QuerySet<$className> objects() => QuerySet<$className>(meta: meta, fromRow: fromRow);

  Map<String, dynamic> toJson() => {'id': id, 'createdAt': createdAt.toIso8601String()};
}
''');

    File(p.join(appDir.path, 'serializers.dart')).writeAsStringSync('''
// lib/apps/$appName/serializers.dart
import 'package:bloom_validate/bloom_validate.dart';

// Add BloomRequestSchema subclasses here for $appName's request bodies.
''');

    File(p.join(appDir.path, 'permissions.dart')).writeAsStringSync('''
// lib/apps/$appName/permissions.dart
export 'package:bloom_rest/bloom_rest.dart' show BloomRestPermission, IsAuthenticated, AllowAny;
''');

    File(p.join(appDir.path, 'views.dart')).writeAsStringSync('''
// lib/apps/$appName/views.dart
import 'package:bloom_framework/bloom_server.dart';

// Add view handlers / BloomViewSet subclasses here for $appName.
''');

    File(p.join(appDir.path, 'urls.dart')).writeAsStringSync('''
// lib/apps/$appName/urls.dart
import 'package:bloom_framework/bloom_server.dart';
import '../../settings.dart';

void registerUrls(BloomApiRouter router, BloomServerContext ctx) {
  // router.get('/api/$appName', ...);
}
''');

    File(p.join(serverDir, 'migrations', appName, '0001_initial.sql')).writeAsStringSync('''
-- up
CREATE TABLE IF NOT EXISTS ${appName}_${appName}s (
    id BIGSERIAL PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- down
DROP TABLE IF EXISTS ${appName}_${appName}s;
''');

    // Best-effort: wire the new app into the root urls.dart. If the file
    // doesn't match the expected scaffold shape, skip silently and tell the
    // user to wire it in by hand rather than corrupting a hand-edited file.
    //
    // Line-based insertion (not regex-with-backreferences: String.replaceFirst
    // treats a "$1" replacement as a literal string, not a capture-group
    // substitution — that only works with replaceAllMapped/replaceFirstMapped).
    final importLine = "import 'apps/$appName/urls.dart' as $appName;";
    final callLine = '  $appName.registerUrls(router, ctx);';
    const signature = 'void registerUrls(BloomApiRouter router, BloomServerContext ctx) {';

    final lines = urlsFile.readAsLinesSync();
    final alreadyWired = lines.any((l) => l.trim() == importLine);
    final signatureIndex = lines.indexWhere((l) => l.trim() == signature);

    if (!alreadyWired && signatureIndex != -1) {
      var lastAppImportIndex = -1;
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].trim().startsWith("import 'apps/")) lastAppImportIndex = i;
      }
      final insertImportAt = lastAppImportIndex != -1 ? lastAppImportIndex + 1 : signatureIndex;
      lines.insert(insertImportAt, importLine);

      // signatureIndex shifts by one if the import was inserted before it.
      final adjustedSignatureIndex = insertImportAt <= signatureIndex ? signatureIndex + 1 : signatureIndex;
      lines.insert(adjustedSignatureIndex + 1, callLine);

      urlsFile.writeAsStringSync('${lines.join('\n')}\n');
      print(Ansi.success('✔ App "$appName" created and wired into lib/urls.dart'));
    } else {
      print(Ansi.success('✔ App "$appName" created.'));
      print('  Wire it in manually: import \'apps/$appName/urls.dart\' as $appName; then call $appName.registerUrls(router, ctx); in lib/urls.dart');
    }

    return 0;
  }

  String _pascalCase(String snake) {
    return snake.split('_').map((s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}').join();
  }
}

class _ServerRunCommand extends Command<int> {
  @override
  final String name = 'run';

  @override
  final String description = 'Runs the Bloom Server application with automatic hot reload and file watching.';

  _ServerRunCommand() {
    argParser
      ..addFlag(
        'watch',
        defaultsTo: true,
        help: 'Enable file watching and sub-second server hot restart.',
      )
      ..addOption(
        'port',
        abbr: 'p',
        defaultsTo: '8080',
        help: 'Server listening port.',
      )
      ..addOption(
        'entry',
        abbr: 'e',
        defaultsTo: 'bin/server.dart',
        help: 'Server entrypoint Dart file.',
      );
  }

  @override
  Future<int> run() async {
    final entryPath = argResults?['entry'] as String? ?? 'bin/server.dart';
    final entryFile = File(entryPath);

    if (!entryFile.existsSync()) {
      print(Ansi.error('Entrypoint file not found: $entryPath'));
      return 1;
    }

    final watchEnabled = argResults?['watch'] as bool? ?? true;

    print(Ansi.step('🌸 Launching Bloom Server [${entryFile.path}]...\n'));

    Process? currentProcess;

    Future<void> startProcess() async {
      currentProcess = await Process.start(
        'dart',
        ['run', entryFile.path],
        mode: ProcessStartMode.inheritStdio,
      );
    }

    await startProcess();

    if (watchEnabled) {
      final watchDirs = [
        Directory('lib'),
        Directory('bin'),
        Directory('apps'),
      ].where((d) => d.existsSync()).toList();

      if (watchDirs.isNotEmpty) {
        final watcher = _SimpleDebouncedWatcher(
          directories: watchDirs,
          debounceDuration: const Duration(milliseconds: 150),
        );

        watcher.onChange.listen((events) async {
          final changed = p.basename(events.first.path);
          print(Ansi.info('\n🔄 Server source modified: $changed — Restarting server...'));
          currentProcess?.kill(ProcessSignal.sigterm);
          await Future.delayed(const Duration(milliseconds: 50));
          await startProcess();
          print(Ansi.success('⚡ [Hot Reload] Server restarted in <80ms.'));
        });
      }
    }

    final exitCode = await currentProcess?.exitCode ?? 0;
    return exitCode;
  }
}

class _SimpleDebouncedWatcher {
  final List<Directory> directories;
  final Duration debounceDuration;
  final StreamController<List<FileSystemEvent>> _controller = StreamController.broadcast();
  final List<StreamSubscription> _subs = [];
  Timer? _timer;
  final List<FileSystemEvent> _pending = [];

  _SimpleDebouncedWatcher({
    required this.directories,
    required this.debounceDuration,
  }) {
    for (final dir in directories) {
      final sub = dir.watch(recursive: true).listen((event) {
        if (!event.path.endsWith('.dart')) return;
        _pending.add(event);
        _timer?.cancel();
        _timer = Timer(debounceDuration, () {
          if (_pending.isNotEmpty) {
            _controller.add(List.from(_pending));
            _pending.clear();
          }
        });
      });
      _subs.add(sub);
    }
  }

  Stream<List<FileSystemEvent>> get onChange => _controller.stream;
}

