import 'dart:typed_data';

import 'package:dartloom_runtime/dartloom_runtime.dart';
import 'package:dartloom_settings/dartloom_settings.dart';
import 'package:dartloom_storage/dartloom_storage.dart';
import 'package:dartloom_sync/dartloom_sync.dart';
import 'package:dartloom_sync_etag/dartloom_sync_etag.dart';
import 'package:dartloom_sync_webdav/dartloom_sync_webdav.dart';

import '../features/todos/data/todo_repository.dart';
import 'sync_configuration.dart';

Future<DartloomBinding<Object>> createAppSync(
  DartloomFactoryContext context,
) async {
  return DartloomBinding<SyncEngine>(
    ConfiguredWebDavSyncEngine(
      settings: context.get<SettingsStore>(),
      jsonStore: context.get<JsonStore>(name: 'json'),
      defaultRootPath:
          context.options['backend_root_path'] as String? ?? 'MiniTodo',
    ),
  );
}

final class ConfiguredWebDavSyncEngine implements SyncEngine {
  ConfiguredWebDavSyncEngine({
    required this.settings,
    required this.jsonStore,
    required this.defaultRootPath,
  });

  final SettingsStore settings;
  final JsonStore jsonStore;
  final String defaultRootPath;
  SyncStatus _status = SyncStatus.idle;
  List<SyncConflict> _conflicts = const [];

  @override
  Future<SyncResult> sync() async {
    if (_status == SyncStatus.syncing) {
      return const SyncResult(
        status: SyncStatus.failed,
        message: 'A sync is already running.',
      );
    }

    _status = SyncStatus.syncing;
    try {
      final configuration = await _readConfiguration();
      final delegate = EtagSyncEngine(
        local: _TodoLocalSyncStore(jsonStore),
        remote: _TodoRemoteObjectStore(
          WebDavObjectStore(
            baseUrl: configuration.url,
            rootPath: configuration.rootPath,
            username: configuration.username,
            password: configuration.password,
          ),
        ),
        stateStore: JsonSyncStateStore(
          jsonStore,
          key:
              '__dartloom_sync/todos-v2/${Uri.encodeComponent(configuration.stateKey)}',
        ),
      );
      final result = await delegate.sync();
      _conflicts = await delegate.conflicts();
      _status = result.status;
      return result;
    } on Object catch (error) {
      _conflicts = const [];
      _status = SyncStatus.failed;
      return SyncResult(status: _status, message: error.toString());
    }
  }

  @override
  Future<SyncStatus> status() async => _status;

  @override
  Future<List<SyncConflict>> conflicts() async => List.unmodifiable(_conflicts);

  Future<_WebDavConfiguration> _readConfiguration() async {
    final urlValue = await settings.read(syncWebDavUrlKey);
    final urlText = urlValue is String ? urlValue.trim() : '';
    final url = Uri.tryParse(urlText);
    if (url == null ||
        (url.scheme != 'http' && url.scheme != 'https') ||
        url.host.isEmpty) {
      throw const FormatException('A valid WebDAV URL is required.');
    }

    final rootValue = await settings.read(syncWebDavRootPathKey);
    final rootPath = (rootValue is String ? rootValue.trim() : '');
    final usernameValue = await settings.read(syncWebDavUsernameKey);
    final passwordValue = await settings.read(syncWebDavPasswordKey);

    return _WebDavConfiguration(
      url: url,
      rootPath: rootPath.isEmpty ? defaultRootPath : rootPath,
      username: usernameValue is String ? usernameValue : '',
      password: passwordValue is String ? passwordValue : '',
    );
  }
}

final class _WebDavConfiguration {
  const _WebDavConfiguration({
    required this.url,
    required this.rootPath,
    required this.username,
    required this.password,
  });

  final Uri url;
  final String rootPath;
  final String username;
  final String password;

  String get stateKey => '$url|$rootPath|$username';
}

final class _TodoLocalSyncStore implements LocalSyncStore {
  _TodoLocalSyncStore(JsonStore store) : _delegate = JsonLocalSyncStore(store);

  final JsonLocalSyncStore _delegate;

  @override
  Future<void> delete(String key) => _delegate.delete(key);

  @override
  Future<List<String>> list() async => (await _delegate.list())
      .where(TodoStorageKeys.isTodoKey)
      .toList(growable: false);

  @override
  Future<Uint8List?> read(String key) => _delegate.read(key);

  @override
  Future<void> write(String key, Uint8List data) => _delegate.write(key, data);
}

final class _TodoRemoteObjectStore implements RemoteObjectStore {
  const _TodoRemoteObjectStore(this._delegate);

  final RemoteObjectStore _delegate;

  @override
  Future<void> delete(String key, {String? ifMatch}) =>
      _delegate.delete(key, ifMatch: ifMatch);

  @override
  Future<void> initialize() => _delegate.initialize();

  @override
  Future<List<RemoteObjectMetadata>> list() async => (await _delegate.list())
      .where((item) => TodoStorageKeys.isTodoKey(item.key))
      .toList(growable: false);

  @override
  Future<SyncObject?> read(String key) => _delegate.read(key);

  @override
  Future<String> write(
    String key,
    Uint8List data, {
    String? ifMatch,
    bool createOnly = false,
  }) => _delegate.write(key, data, ifMatch: ifMatch, createOnly: createOnly);
}
