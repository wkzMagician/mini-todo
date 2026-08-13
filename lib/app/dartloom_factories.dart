import 'package:dartloom_runtime/dartloom_runtime.dart';
import 'package:dartloom_storage/dartloom_storage.dart';
import 'package:dartloom_storage_json_file/dartloom_storage_json_file.dart';

import 'app_paths.dart';

Future<DartloomBinding<Object>> createJsonReplicaStore(
  DartloomFactoryContext context,
) async {
  final paths = await MiniTodoPaths.resolve();
  final store = await JsonDirectoryStore.openAt(
    directory: paths.businessRoot,
    metadataDirectory: paths.metadataRoot,
    allowedKeys: const {'.mini-todo.json'},
    allowedPrefixes: const ['todo-'],
    seed: const {
      '.mini-todo.json': {
        'application': 'mini-todo',
        'layout': 1,
        'format': 'json-files',
      },
    },
  );
  return DartloomBinding<ReplicaStore>(store, dispose: store.close);
}

final dartloomApplicationFactories = <String, DartloomFactory>{
  'createJsonReplicaStore': createJsonReplicaStore,
};
