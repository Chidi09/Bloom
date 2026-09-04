// test/model_generator_test.dart
import 'package:bloom_db_generator/src/model_generator.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

// ignore: subtype_of_sealed_class
class _FakeBuildStep implements BuildStep {
  final Resolver _resolver;
  final AssetId _inputId;

  _FakeBuildStep(this._resolver, [String pkg = 'test_pkg'])
      : _inputId = AssetId(pkg, 'lib/test_model.dart');

  @override
  AssetId get inputId => _inputId;

  @override
  Resolver get resolver => _resolver;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<String> _generateFor(String source,
    [String className = 'TestModel']) async {
  late String output;
  await resolveSource(source, (resolver) async {
    final lib = await resolver.findLibraryByName('test_lib');
    expect(lib, isNotNull, reason: 'test_lib library not found');
    final classElement = lib!.getClass(className);
    expect(classElement, isNotNull, reason: '$className class not found');
    final modelAnnotation = classElement!.metadata
        .firstWhere((a) =>
            a.computeConstantValue()?.type?.element?.name == 'BloomModel')
        .computeConstantValue();
    final annotation = ConstantReader(modelAnnotation);
    final generator = ModelGenerator();
    output = generator.generateForAnnotatedElement(
      classElement,
      annotation,
      _FakeBuildStep(resolver),
    );
  });
  return output;
}

void main() {
  group('ModelGenerator', () {
    test('instantiates generator correctly', () {
      final generator = ModelGenerator();
      expect(generator, isNotNull);
    });

    test('infers standard defaults when @BloomField is omitted', () async {
      final output = await _generateFor(r'''
library test_lib;
import 'package:bloom_db/bloom_db.dart';

@BloomModel(app: 'store', tableName: 'store_products')
class TestModel {
  final int id;
  final String title;
  final String? subtitle;
  final double rating;
  final bool isAvailable;
  final DateTime createdAt;
}
''');

      expect(output, contains("structName: 'TestModel'"));
      expect(output, contains("appLabel: 'store'"));
      expect(output, contains("tableName: 'store_products'"));

      // id: inferred as PK, auto, non-nullable bigInt
      expect(output, contains(r'''
    FieldMeta(
      name: 'id',
      columnName: 'id',
      kind: FieldKind.bigInt,
      nullable: false,
      primaryKey: true,
      auto: true,
      unique: false,
      dbIndex: false,
    ),'''));

      // title: non-nullable text
      expect(output, contains(r'''
    FieldMeta(
      name: 'title',
      columnName: 'title',
      kind: FieldKind.text,
      nullable: false,
      primaryKey: false,
      auto: false,
      unique: false,
      dbIndex: false,
    ),'''));

      // subtitle: nullable text
      expect(output, contains(r'''
    FieldMeta(
      name: 'subtitle',
      columnName: 'subtitle',
      kind: FieldKind.text,
      nullable: true,
      primaryKey: false,
      auto: false,
      unique: false,
      dbIndex: false,
    ),'''));

      // rating: float
      expect(output, contains(r'''
    FieldMeta(
      name: 'rating',
      columnName: 'rating',
      kind: FieldKind.float,
      nullable: false,
      primaryKey: false,
      auto: false,
      unique: false,
      dbIndex: false,
    ),'''));

      // isAvailable: boolean
      expect(output, contains(r'''
    FieldMeta(
      name: 'isAvailable',
      columnName: 'is_available',
      kind: FieldKind.boolean,
      nullable: false,
      primaryKey: false,
      auto: false,
      unique: false,
      dbIndex: false,
    ),'''));

      // createdAt: dateTime
      expect(output, contains(r'''
    FieldMeta(
      name: 'createdAt',
      columnName: 'created_at',
      kind: FieldKind.dateTime,
      nullable: false,
      primaryKey: false,
      auto: false,
      unique: false,
      dbIndex: false,
    ),'''));
    });

    test('infers defaults when empty @BloomField() is used', () async {
      final output = await _generateFor(r'''
library test_lib;
import 'package:bloom_db/bloom_db.dart';

@BloomModel(app: 'store')
class TestModel {
  @BloomField()
  final int id;

  @BloomField()
  final String? notes;
}
''');

      // id: inferred as PK, auto
      expect(output, contains(r'''
    FieldMeta(
      name: 'id',
      columnName: 'id',
      kind: FieldKind.bigInt,
      nullable: false,
      primaryKey: true,
      auto: true,
      unique: false,
      dbIndex: false,
    ),'''));

      // notes: inferred nullable from Dart type
      expect(output, contains(r'''
    FieldMeta(
      name: 'notes',
      columnName: 'notes',
      kind: FieldKind.text,
      nullable: true,
      primaryKey: false,
      auto: false,
      unique: false,
      dbIndex: false,
    ),'''));
    });

    test('preserves explicit primaryKey: false on field named id', () async {
      final output = await _generateFor(r'''
library test_lib;
import 'package:bloom_db/bloom_db.dart';

@BloomModel(app: 'core')
class TestModel {
  @BloomField(primaryKey: false)
  final int id;

  @BloomField(primaryKey: true)
  final String slug;
}
''');

      // id must have primaryKey: false and auto: false
      expect(output, contains(r'''
    FieldMeta(
      name: 'id',
      columnName: 'id',
      kind: FieldKind.bigInt,
      nullable: false,
      primaryKey: false,
      auto: false,
      unique: false,
      dbIndex: false,
    ),'''));

      // slug must have primaryKey: true
      expect(output, contains(r'''
    FieldMeta(
      name: 'slug',
      columnName: 'slug',
      kind: FieldKind.text,
      nullable: false,
      primaryKey: true,
      auto: false,
      unique: false,
      dbIndex: false,
    ),'''));

      // ordering must use slug as pk
      expect(output, contains("ordering: ['slug']"));
    });

    test('preserves explicit auto: false on primary key field', () async {
      final output = await _generateFor(r'''
library test_lib;
import 'package:bloom_db/bloom_db.dart';

@BloomModel(app: 'core')
class TestModel {
  @BloomField(auto: false)
  final int id;
}
''');

      // id is PK, but auto is explicitly false
      expect(output, contains(r'''
    FieldMeta(
      name: 'id',
      columnName: 'id',
      kind: FieldKind.bigInt,
      nullable: false,
      primaryKey: true,
      auto: false,
      unique: false,
      dbIndex: false,
    ),'''));

      // Since auto is false, saveCols must include 'id'
      expect(output, contains("final saveCols = <String>['id'];"));
    });

    test('preserves explicit nullable: false on nullable Dart type', () async {
      final output = await _generateFor(r'''
library test_lib;
import 'package:bloom_db/bloom_db.dart';

@BloomModel(app: 'core')
class TestModel {
  final int id;

  @BloomField(nullable: false)
  final String? overrideNullable;
}
''');

      expect(output, contains(r'''
    FieldMeta(
      name: 'overrideNullable',
      columnName: 'override_nullable',
      kind: FieldKind.text,
      nullable: false,
      primaryKey: false,
      auto: false,
      unique: false,
      dbIndex: false,
    ),'''));
    });

    test('preserves explicit nullable: true on non-nullable Dart type',
        () async {
      final output = await _generateFor(r'''
library test_lib;
import 'package:bloom_db/bloom_db.dart';

@BloomModel(app: 'core')
class TestModel {
  final int id;

  @BloomField(nullable: true)
  final String explicitNull;
}
''');

      expect(output, contains(r'''
    FieldMeta(
      name: 'explicitNull',
      columnName: 'explicit_null',
      kind: FieldKind.text,
      nullable: true,
      primaryKey: false,
      auto: false,
      unique: false,
      dbIndex: false,
    ),'''));
    });

    test('preserves custom column name, kind, unique, and dbIndex metadata',
        () async {
      final output = await _generateFor(r'''
library test_lib;
import 'package:bloom_db/bloom_db.dart';

@BloomModel(app: 'auth')
class TestModel {
  @idField
  final int id;

  @BloomField(
    column: 'email_address',
    kind: FieldKind.char,
    unique: true,
    dbIndex: true,
  )
  final String email;

  @BloomField(
    kind: FieldKind.decimal(precision: 12, scale: 4),
  )
  final double balance;

  @BloomField(
    unique: false,
    dbIndex: false,
  )
  final String description;
}
''');

      // id: generated from @idField
      expect(output, contains(r'''
    FieldMeta(
      name: 'id',
      columnName: 'id',
      kind: FieldKind.bigInt,
      nullable: false,
      primaryKey: true,
      auto: true,
      unique: false,
      dbIndex: false,
    ),'''));

      // email: custom column, kind: char, unique: true, dbIndex: true
      expect(output, contains(r'''
    FieldMeta(
      name: 'email',
      columnName: 'email_address',
      kind: FieldKind.char,
      nullable: false,
      primaryKey: false,
      auto: false,
      unique: true,
      dbIndex: true,
    ),'''));

      // balance: custom decimal kind with precision and scale
      expect(output, contains(r'''
    FieldMeta(
      name: 'balance',
      columnName: 'balance',
      kind: const FieldKind.decimal(precision: 12, scale: 4),
      nullable: false,
      primaryKey: false,
      auto: false,
      unique: false,
      dbIndex: false,
    ),'''));

      // description: explicit unique: false, dbIndex: false
      expect(output, contains(r'''
    FieldMeta(
      name: 'description',
      columnName: 'description',
      kind: FieldKind.text,
      nullable: false,
      primaryKey: false,
      auto: false,
      unique: false,
      dbIndex: false,
    ),'''));
    });

    test('preserves maxLength and defaultVal metadata', () async {
      final output = await _generateFor(r'''
library test_lib;
import 'package:bloom_db/bloom_db.dart';

@BloomModel(app: 'catalog')
class TestModel {
  @idField
  final int id;

  @BloomField(
    maxLength: 50,
    defaultVal: DefaultValue.text('pending'),
  )
  final String status;
}
''');

      expect(output, contains("maxLength: 50"));
      expect(
          output, contains("defaultVal: const DefaultValue.text('pending')"));
      expect(output, contains("name: 'status'"));
    });

    test(
        'preserves primary key inference when @BloomField only specifies custom column',
        () async {
      final output = await _generateFor(r'''
library test_lib;
import 'package:bloom_db/bloom_db.dart';

@BloomModel(app: 'billing')
class TestModel {
  @BloomField(column: 'item_id')
  final int id;

  final String name;
}
''');

      // id should still be inferred as primaryKey: true and auto: true
      expect(output, contains(r'''
    FieldMeta(
      name: 'id',
      columnName: 'item_id',
      kind: FieldKind.bigInt,
      nullable: false,
      primaryKey: true,
      auto: true,
      unique: false,
      dbIndex: false,
    ),'''));
    });

    test(
        'preserves explicit primaryKey: true with inferred or explicit auto on non-id fields',
        () async {
      final output = await _generateFor(r'''
library test_lib;
import 'package:bloom_db/bloom_db.dart';

@BloomModel(app: 'inventory')
class TestModel {
  @BloomField(primaryKey: true, auto: true)
  final int itemId;

  @BloomField(column: 'item_uuid', kind: FieldKind.uuid, unique: true)
  final String uuid;

  @BloomField(kind: FieldKind.json)
  final String payload;
}
''');

      expect(output, contains(r'''
    FieldMeta(
      name: 'itemId',
      columnName: 'item_id',
      kind: FieldKind.bigInt,
      nullable: false,
      primaryKey: true,
      auto: true,
      unique: false,
      dbIndex: false,
    ),'''));

      expect(output, contains(r'''
    FieldMeta(
      name: 'uuid',
      columnName: 'item_uuid',
      kind: FieldKind.uuid,
      nullable: false,
      primaryKey: false,
      auto: false,
      unique: true,
      dbIndex: false,
    ),'''));

      expect(output, contains(r'''
    FieldMeta(
      name: 'payload',
      columnName: 'payload',
      kind: FieldKind.json,
      nullable: false,
      primaryKey: false,
      auto: false,
      unique: false,
      dbIndex: false,
    ),'''));

      expect(output, contains("ordering: ['itemId']"));
    });

    test('preserves string primary key with inferred auto: false', () async {
      final output = await _generateFor(r'''
library test_lib;
import 'package:bloom_db/bloom_db.dart';

@BloomModel(app: 'system')
class TestModel {
  @BloomField(primaryKey: true)
  final String code;

  final String name;
}
''');

      expect(output, contains(r'''
    FieldMeta(
      name: 'code',
      columnName: 'code',
      kind: FieldKind.text,
      nullable: false,
      primaryKey: true,
      auto: false,
      unique: false,
      dbIndex: false,
    ),'''));

      // saveCols must include 'code' since auto is false
      expect(output, contains("final saveCols = <String>['code', 'name'];"));
    });

    test('throws for uninferrable Dart types instead of mapping to text (#15)',
        () async {
      await expectLater(
        _generateFor(r'''
library test_lib;
import 'dart:typed_data';
import 'package:bloom_db/bloom_db.dart';

@BloomModel(table: 'blobs')
class TestModel {
  final int id;
  final Uint8List payload;
  TestModel({required this.id, required this.payload});
}
'''),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('generated fromRow throws on null for non-nullable fields (#15)',
        () async {
      final output = await _generateFor(r'''
library test_lib;
import 'package:bloom_db/bloom_db.dart';

@BloomModel(table: 'strict_users')
class TestModel {
  final int id;
  final String name;
  final int age;
  TestModel({required this.id, required this.name, required this.age});
}
''');

      // No silent default fallbacks.
      expect(output, isNot(contains("?? ''")));
      expect(output, isNot(contains('?? 0')));
      expect(output, isNot(contains('fromMillisecondsSinceEpoch(0')));
      // Loud failure instead.
      expect(
        output,
        contains(
            "throw StateError('Null value for non-nullable field name (name) in table test_pkg_test_model')"),
      );
      expect(
        output,
        contains(
            "throw StateError('Null value for non-nullable field age (age) in table test_pkg_test_model')"),
      );
    });

    test('generated fromRow still allows nullable fields (#15)', () async {
      final output = await _generateFor(r'''
library test_lib;
import 'package:bloom_db/bloom_db.dart';

@BloomModel(table: 'lenient_users')
class TestModel {
  final int id;
  final String? nickname;
  TestModel({required this.id, this.nickname});
}
''');

      expect(output, contains("row.tryStringByName('nickname')"));
      expect(output, isNot(contains("Null value for non-nullable field nickname")));
    });
  });
}
