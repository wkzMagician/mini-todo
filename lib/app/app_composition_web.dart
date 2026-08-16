import 'package:dartloom_logging_logger/dartloom_logging_logger.dart';
import 'package:dartloom_settings_secure_storage/dartloom_settings_secure_storage.dart';
import 'package:dartloom_settings_shared_preferences/dartloom_settings_shared_preferences.dart';
import 'package:dartloom_storage_indexeddb/dartloom_storage_indexeddb.dart';
import 'package:dartloom_sync/dartloom_sync.dart';
import 'package:dartloom_sync_etag/dartloom_sync_etag.dart';
import 'package:dartloom_sync_flutter/dartloom_sync_flutter.dart';
import 'package:dartloom_sync_storage/dartloom_sync_storage.dart';
import 'package:dartloom_sync_webdav/dartloom_sync_webdav.dart';

import '../features/todos/data/todo_repository.dart';
import 'app_services.dart';

/// Browser composition uses the persistent IndexedDB ObjectStore adapter.
/// Data and sync journal records live in separate namespaces as required by
/// Dartloom Sync's journaled replica bridge.
Future<AppServices> createApplicationServices() async {
  final settings = SharedPreferencesSettingsStore();
  final secrets = const SecureSettingsStore();
  final logger = LoggerAppLogger();
  final objects = IndexedDbObjectStore(namespace: 'mini-todo-objects');
  final metadata = IndexedDbObjectStore(namespace: 'mini-todo-sync');
  final scope = await SyncProfileScope.open(settings, 'default');
  final signals = FlutterSyncRuntimeSignals();
  await signals.start();
  final sync = SyncCoordinator(
    instanceName: 'default',
    policy: SyncPolicyCodec.resolve(_syncPolicy, 'web'),
    profiles: SettingsSyncProfileRepository(
      instanceName: 'default',
      metadata: settings,
      secretsStore: secrets,
      scope: scope,
    ),
    localFactory: ObjectStoreLocalReplicaFactory(
      objects: objects,
      metadata: metadata,
    ),
    stateRepository: SettingsReconciliationStateRepository(
      settings,
      instanceName: 'default',
    ),
    reconciler: const EtagReconciler(),
    backends: {'webdav': WebDavBackendFactory(defaultRootPath: 'MiniTodo')},
    runtimeSignals: signals,
  );
  await sync.start();

  return AppServices(
    repository: ObjectStoreTodoRepository(objects),
    settings: settings,
    logger: logger,
    sync: sync,
    dispose: () async {
      await sync.dispose();
      await signals.dispose();
      await scope.dispose();
    },
  );
}

const _syncPolicy = <String, Object?>{
  'mode': 'automatic',
  'triggers': {
    'startup': true,
    'resume': true,
    'connectivity_restored': true,
    'local_write': {'enabled': true, 'debounce': '2s', 'max_delay': '10s'},
  },
  'discovery': {
    'remote_changes': 'auto',
    'poll_interval': '5m',
    'safety_reconcile_interval': '15m',
  },
  'execution': {
    'timeout': '2m',
    'busy_behavior': 'coalesce_then_rerun',
    'max_parallel_transfers': 4,
    'max_object_size': '20mb',
  },
  'retry': {
    'strategy': 'exponential',
    'initial_delay': '5s',
    'fixed_delay': '30s',
    'sequence': ['5s', '30s', '2m', '10m'],
    'multiplier': 3,
    'max_delay': '10m',
    'jitter': '20%',
    'max_attempts': 0,
  },
  'conflicts': {'strategy': 'preserve', 'delete_vs_update': 'conflict'},
  'state': {'base_payload': 'always', 'tombstone_retention': '30d'},
  'profiles': {'sync_on_activate': true, 'existing_data': 'attach_to_default'},
};
