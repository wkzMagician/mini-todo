import 'dart:io';

import 'package:dartloom_autostart/dartloom_autostart.dart';
import 'package:dartloom_autostart_launch_at_startup/dartloom_autostart_launch_at_startup.dart';
import 'package:dartloom_logging_logger/dartloom_logging_logger.dart';
import 'package:dartloom_resident/dartloom_resident.dart';
import 'package:dartloom_resident_tray/dartloom_resident_tray.dart';
import 'package:dartloom_settings_secure_storage/dartloom_settings_secure_storage.dart';
import 'package:dartloom_settings_shared_preferences/dartloom_settings_shared_preferences.dart';
import 'package:dartloom_singleton/dartloom_singleton.dart';
import 'package:dartloom_singleton_socket/dartloom_singleton_socket.dart';
import 'package:dartloom_storage_file/dartloom_storage_file.dart';
import 'package:dartloom_sync/dartloom_sync.dart';
import 'package:dartloom_sync_etag/dartloom_sync_etag.dart';
import 'package:dartloom_sync_flutter/dartloom_sync_flutter.dart';
import 'package:dartloom_sync_storage/dartloom_sync_storage.dart';
import 'package:dartloom_sync_webdav/dartloom_sync_webdav.dart';
import 'package:dartloom_sync_workmanager/dartloom_sync_workmanager.dart';
import 'package:flutter/foundation.dart';

import '../features/todos/data/todo_repository.dart';
import 'app_paths.dart';
import 'app_services.dart';

Future<AppServices> createApplicationServices() => _compose();

Future<AppServices> _compose({bool background = false}) async {
  final settings = SharedPreferencesSettingsStore();
  final secrets = const SecureSettingsStore();
  final logger = LoggerAppLogger();
  final paths = await MiniTodoPaths.resolve();
  final store = await FileObjectStore.open(
    root: paths.businessRoot,
    hierarchical: false,
  );
  final metadata = await FileObjectStore.open(
    root: paths.metadataRoot,
    hierarchical: false,
  );
  final scope = await SyncProfileScope.open(settings, 'default');
  final signals = background ? null : FlutterSyncRuntimeSignals();
  await signals?.start();
  final sync = SyncCoordinator(
    instanceName: 'default',
    policy: SyncPolicyCodec.resolve(_syncPolicy, _platformName),
    profiles: SettingsSyncProfileRepository(
      instanceName: 'default',
      metadata: settings,
      secretsStore: secrets,
      scope: scope,
    ),
    localFactory: ObjectStoreLocalReplicaFactory(
      objects: store,
      metadata: metadata,
    ),
    stateRepository: SettingsReconciliationStateRepository(
      settings,
      instanceName: 'default',
    ),
    reconciler: const EtagReconciler(),
    backends: {
      'webdav': WebDavBackendFactory(
        defaultRootPath: 'MiniTodo',
        connectTimeout: const Duration(seconds: 10),
        requestTimeout: const Duration(seconds: 30),
        maxParallelRequests: 4,
        createMissingCollections: true,
        hierarchical: false,
        probeDepthInfinity: false,
        legacyCollection: 'json',
        legacyKeyPrefix: 'todo-',
        listingLimitHint: 750,
      ),
    },
    runtimeSignals: signals,
    backgroundScheduler: background
        ? null
        : WorkmanagerSyncBackgroundScheduler(
            callbackDispatcher: miniTodoSyncCallbackDispatcher,
          ),
  );
  await sync.start();

  ResidentService? resident;
  AutostartService? autostart;
  SingleInstanceService? singleInstance;
  if (!background && _isDesktop) {
    final tray = TrayResidentService(
      tooltip: 'Mini Todo',
      linuxIconPath: 'assets/tray_icon.png',
    );
    await tray.initialize(iconPath: 'windows/runner/resources/app_icon.ico');
    resident = tray;
    autostart = LaunchAtStartupService(
      appName: 'mini_todo',
      appPath: Platform.resolvedExecutable,
      packageName: 'com.example.mini_todo',
    );
    singleInstance = SocketSingleInstanceService(resident: resident);
  }

  return AppServices(
    repository: ObjectStoreTodoRepository(store),
    settings: settings,
    logger: logger,
    autostart: autostart,
    sync: sync,
    resident: resident,
    singleInstance: singleInstance,
    dispose: () async {
      await singleInstance?.dispose();
      await resident?.dispose();
      await sync.dispose();
      await signals?.dispose();
      await scope.dispose();
    },
  );
}

bool get _isDesktop => {
  TargetPlatform.windows,
  TargetPlatform.macOS,
  TargetPlatform.linux,
}.contains(defaultTargetPlatform);

String get _platformName => switch (defaultTargetPlatform) {
  TargetPlatform.android => 'android',
  TargetPlatform.iOS => 'ios',
  TargetPlatform.windows => 'windows',
  TargetPlatform.macOS => 'macos',
  TargetPlatform.linux => 'linux',
  _ => 'windows',
};

@pragma('vm:entry-point')
void miniTodoSyncCallbackDispatcher() {
  executeDartloomSyncWorker((_) async {
    final services = await _compose(background: true);
    return DartloomSyncWorkerSession(
      run: () async => (await services.sync!.syncNow()).isSuccess,
      dispose: services.dispose,
    );
  });
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
  'platforms': {
    'android': {
      'background': {
        'enabled': true,
        'enqueue_on_pending': true,
        'periodic_interval': '15m',
        'flex_interval': '5m',
        'network': 'connected',
        'requires_battery_not_low': true,
        'requires_charging': false,
        'requires_network': true,
        'timeout': '2m',
      },
    },
  },
};
