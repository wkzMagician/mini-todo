import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartloom_storage/dartloom_storage.dart';
import 'package:dartloom_storage_json_file/dartloom_storage_json_file.dart';
import 'package:dartloom_sync/dartloom_sync.dart';
import 'package:dartloom_sync_etag/dartloom_sync_etag.dart';
import 'package:dartloom_sync_storage/dartloom_sync_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'root loss and external changes recover without remote mutations',
    () async {
      final sandbox = await Directory.systemTemp.createTemp(
        'mini_todo_remote_restore_',
      );
      final business = Directory(
        '${sandbox.path}${Platform.pathSeparator}MiniTodo',
      );
      final metadata = Directory(
        '${sandbox.path}${Platform.pathSeparator}metadata',
      );
      final remote = _MemoryRemote();
      final state = _MemoryState();
      var store = await _open(business, metadata);
      var local = await ReplicaStoreLocalReplicaFactory(store).open('default');

      try {
        await store.write('todo-1', {'title': 'one'});
        await store.write('todo-2', {'title': 'two'});
        await const EtagReconciler().reconcile(_request(local, remote, state));
        expect(await store.explicitIntents(), isEmpty);
        final remoteBefore = remote.snapshot();
        final writesBefore = remote.writeCount;
        final deletesBefore = remote.deleteCount;

        await local.close();
        await store.close();
        await business.delete(recursive: true);
        store = await _open(business, metadata);
        local = await ReplicaStoreLocalReplicaFactory(store).open('default');

        final report = await const EtagReconciler().reconcile(
          _request(local, remote, state),
        );

        expect(report.downloaded, 2);
        expect(report.uploaded, 0);
        expect(report.deletedRemotely, 0);
        expect(report.conflicts, 0);
        expect(await store.read('todo-1'), {'title': 'one'});
        expect(await store.read('todo-2'), {'title': 'two'});
        expect(remote.snapshot(), remoteBefore);
        expect(remote.writeCount, writesBefore);
        expect(remote.deleteCount, deletesBefore);

        await File('${business.path}${Platform.pathSeparator}todo-1').delete();
        await File(
          '${business.path}${Platform.pathSeparator}todo-2',
        ).writeAsString(jsonEncode({'title': 'external edit'}));
        await File(
          '${business.path}${Platform.pathSeparator}todo-external',
        ).writeAsString(jsonEncode({'title': 'external new'}));

        final recovery = await const EtagReconciler().reconcile(
          _request(local, remote, state),
        );

        expect(recovery.downloaded, 2);
        expect(await store.read('todo-1'), {'title': 'one'});
        expect(await store.read('todo-2'), {'title': 'two'});
        expect(await store.read('todo-external'), {'title': 'external new'});
        expect(await store.explicitIntents(), isEmpty);
        expect(
          (await store.scan())
              .singleWhere((item) => item.key == 'todo-external')
              .observation,
          ReplicaObservation.unregisteredLocalObject,
        );
        expect(remote.snapshot(), remoteBefore);
        expect(remote.writeCount, writesBefore);
        expect(remote.deleteCount, deletesBefore);
      } finally {
        await local.close();
        await store.close();
        await remote.close();
        if (await sandbox.exists()) {
          await sandbox.delete(recursive: true);
        }
      }
    },
  );

  test(
    'explicit delete propagates but concurrent remote update becomes a conflict',
    () async {
      final sandbox = await Directory.systemTemp.createTemp(
        'mini_todo_delete_conflict_',
      );
      final business = Directory(
        '${sandbox.path}${Platform.pathSeparator}MiniTodo',
      );
      final metadata = Directory(
        '${sandbox.path}${Platform.pathSeparator}metadata',
      );
      final remote = _MemoryRemote();
      final state = _MemoryState();
      final store = await _open(business, metadata);
      final local = await ReplicaStoreLocalReplicaFactory(
        store,
      ).open('default');

      try {
        await store.write('todo-delete', {'title': 'delete me'});
        await store.write('todo-conflict', {'title': 'base'});
        await const EtagReconciler().reconcile(_request(local, remote, state));

        remote.externalWrite(
          'todo-conflict',
          _bytes({'title': 'remote update'}),
        );
        await store.delete('todo-delete');
        await store.delete('todo-conflict');

        final report = await const EtagReconciler().reconcile(
          _request(local, remote, state),
        );
        final conflicts = await state.conflicts('default');

        expect(report.deletedRemotely, 1);
        expect(report.conflicts, 1);
        expect(remote.values, isNot(contains('todo-delete')));
        expect(jsonDecode(utf8.decode(remote.values['todo-conflict']!)), {
          'title': 'remote update',
        });
        expect(conflicts, hasLength(1));
        expect(conflicts.single.key, 'todo-conflict');
        expect(conflicts.single.local, isNull);
        expect(jsonDecode(utf8.decode(conflicts.single.remote!)), {
          'title': 'remote update',
        });
        expect(await store.read('todo-delete'), isNull);
        expect(await store.read('todo-conflict'), isNull);
      } finally {
        await local.close();
        await store.close();
        await remote.close();
        if (await sandbox.exists()) {
          await sandbox.delete(recursive: true);
        }
      }
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

SyncReconcileRequest _request(
  LocalReplica local,
  _MemoryRemote remote,
  _MemoryState state,
) => SyncReconcileRequest(
  profileId: 'default',
  trigger: SyncTrigger.manual,
  local: local,
  remote: remote,
  state: state,
  policy: SyncPolicyCodec.resolve(_policy, 'windows'),
  now: DateTime.utc(2026, 8, 14),
);

final _policy = <String, Object?>{
  'mode': 'manual',
  'triggers': {
    'startup': false,
    'resume': false,
    'connectivity_restored': false,
    'local_write': {'enabled': false, 'debounce': '2s', 'max_delay': '10s'},
  },
  'discovery': {
    'remote_changes': 'disabled',
    'poll_interval': '60s',
    'safety_reconcile_interval': '15m',
  },
  'execution': {
    'timeout': '2m',
    'busy_behavior': 'reject',
    'max_parallel_transfers': 1,
    'max_object_size': '20mb',
  },
  'retry': {
    'strategy': 'none',
    'initial_delay': '5s',
    'fixed_delay': '30s',
    'sequence': <String>[],
    'multiplier': 2,
    'max_delay': '10m',
    'jitter': '0%',
    'max_attempts': 0,
  },
  'conflicts': {'strategy': 'preserve', 'delete_vs_update': 'conflict'},
  'state': {'base_payload': 'always', 'tombstone_retention': '30d'},
  'profiles': {'sync_on_activate': false, 'existing_data': 'attach_to_default'},
};

Uint8List _bytes(Map<String, Object?> value) =>
    Uint8List.fromList(utf8.encode(jsonEncode(value)));

final class _MemoryRemote implements RemoteReplica {
  final values = <String, Uint8List>{};
  final _versions = <String, String>{};
  int _revision = 0;
  int writeCount = 0;
  int deleteCount = 0;

  @override
  String get identity => 'mini-todo-test-remote';

  @override
  RemoteReplicaCapabilities get capabilities => const RemoteReplicaCapabilities(
    deltaScan: false,
    changeFeed: false,
    conditionalWrites: true,
  );

  @override
  Stream<void>? get changeHints => null;

  Map<String, String> snapshot() => {
    for (final entry in values.entries) entry.key: base64Encode(entry.value),
  };

  void externalWrite(String key, Uint8List data) {
    values[key] = Uint8List.fromList(data);
    _versions[key] = 'v${++_revision}';
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<RemoteScan> scan({String? cursor}) async => RemoteScan(
    kind: SyncScanKind.full,
    objects: [
      for (final entry in _versions.entries)
        RemoteObjectMetadata(key: entry.key, version: entry.value),
    ],
    complete: true,
  );

  @override
  Future<RemoteObject?> read(String key) async {
    final value = values[key];
    if (value == null) return null;
    return RemoteObject(
      key: key,
      data: Uint8List.fromList(value),
      version: _versions[key]!,
    );
  }

  @override
  Future<String> write(
    String key,
    Uint8List data, {
    RemoteWriteCondition? condition,
  }) async {
    _checkCondition(key, condition);
    writeCount++;
    externalWrite(key, data);
    return _versions[key]!;
  }

  @override
  Future<void> delete(String key, {RemoteWriteCondition? condition}) async {
    _checkCondition(key, condition);
    deleteCount++;
    values.remove(key);
    _versions.remove(key);
  }

  void _checkCondition(String key, RemoteWriteCondition? condition) {
    if (condition is RemoteCreateCondition && values.containsKey(key)) {
      throw RemotePreconditionException(key);
    }
    if (condition is RemoteVersionCondition &&
        _versions[key] != condition.version) {
      throw RemotePreconditionException(key);
    }
  }

  @override
  Future<void> close() async {}
}

final class _MemoryState implements ReconciliationStateRepository {
  SyncState value = const SyncState();

  @override
  Future<SyncState> load(String profileId) async => value;

  @override
  Future<void> save(String profileId, SyncState state) async => value = state;

  @override
  Future<List<SyncConflict>> conflicts(String profileId) async => value
      .conflicts
      .values
      .map((stored) => stored.value)
      .toList(growable: false);

  @override
  Future<void> resolve(
    String profileId,
    String conflictId,
    SyncConflictResolution resolution,
  ) async {
    final resolutions = Map<String, StoredResolution>.of(value.resolutions)
      ..[conflictId] = StoredResolution(resolution);
    value = value.copyWith(resolutions: resolutions);
  }
}
