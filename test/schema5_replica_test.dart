import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartloom_storage/dartloom_storage.dart';
import 'package:dartloom_storage_json_file/dartloom_storage_json_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory sandbox;
  late Directory business;
  late Directory metadata;
  late JsonDirectoryStore store;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('mini_todo_schema5_');
    business = Directory('${sandbox.path}${Platform.pathSeparator}MiniTodo');
    metadata = Directory('${sandbox.path}${Platform.pathSeparator}metadata');
    store = await _open(business, metadata);
  });

  tearDown(() async {
    await store.close();
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  test(
    'application create update and delete produce durable intents',
    () async {
      await store.write('todo-1', {'title': 'one'});
      await store.write('todo-1', {'title': 'two'});
      await store.delete('todo-1');

      final intents = await store.explicitIntents();

      expect(intents.map((intent) => intent.key), everyElement('todo-1'));
      expect(intents.map((intent) => intent.kind), [
        StoreIntentKind.create,
        StoreIntentKind.update,
        StoreIntentKind.delete,
      ]);
    },
  );

  test(
    'external edit delete and new file never become remote intent',
    () async {
      await store.write('todo-1', {'title': 'baseline'});
      for (final intent in await store.explicitIntents()) {
        await store.forgetExplicitIntent(intent.operationId);
      }
      final existing = File('${business.path}${Platform.pathSeparator}todo-1');
      final unregistered = File(
        '${business.path}${Platform.pathSeparator}todo-external',
      );

      await existing.writeAsString(jsonEncode({'title': 'external'}));
      await store.scan();
      expect(await store.explicitIntents(), isEmpty);

      await existing.delete();
      await store.scan();
      expect(await store.explicitIntents(), isEmpty);

      await unregistered.writeAsString(jsonEncode({'title': 'new'}));
      final scan = await store.scan();
      expect(await store.explicitIntents(), isEmpty);
      expect(
        scan.singleWhere((item) => item.key == 'todo-external').observation,
        ReplicaObservation.unregisteredLocalObject,
      );
    },
  );

  test(
    'missing local root is recreated without authorizing bulk deletion',
    () async {
      await store.write('todo-1', {'title': 'baseline'});
      for (final intent in await store.explicitIntents()) {
        await store.forgetExplicitIntent(intent.operationId);
      }

      await store.close();
      await business.delete(recursive: true);
      store = await _open(business, metadata);

      expect(await business.exists(), isTrue);
      expect(await store.explicitIntents(), isEmpty);
      final scan = await store.scan();
      expect(scan.single.key, 'todo-1');
      expect(scan.single.exists, isFalse);
      expect(scan.single.observation, ReplicaObservation.unexpectedMissing);
    },
  );

  test(
    'recovery writes restore bytes without creating application intent',
    () async {
      final bytes = Uint8List.fromList(utf8.encode('{"title":"remote"}'));

      await store.writeBytes(
        'todo-remote',
        bytes,
        origin: StoreMutationOrigin.recovery,
      );

      expect(await store.readBytes('todo-remote'), bytes);
      expect(await store.explicitIntents(), isEmpty);
    },
  );
}

Future<JsonDirectoryStore> _open(Directory business, Directory metadata) =>
    JsonDirectoryStore.openAt(
      directory: business.absolute,
      metadataDirectory: metadata.absolute,
      allowedKeys: const {'.mini-todo.json'},
      allowedPrefixes: const ['todo-'],
    );
