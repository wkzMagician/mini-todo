import 'package:dartloom_autostart/dartloom_autostart.dart';
import 'package:dartloom_logging/dartloom_logging.dart';
import 'package:dartloom_resident/dartloom_resident.dart';
import 'package:dartloom_settings/dartloom_settings.dart';
import 'package:dartloom_singleton/dartloom_singleton.dart';
import 'package:dartloom_sync/dartloom_sync.dart';

import '../features/todos/data/todo_repository.dart';

/// The application's composition root. Dartloom packages are ordinary
/// collaborators; this class gives the widget tree the dependencies it needs
/// without a service locator or generated registration layer.
final class AppServices {
  AppServices({
    required this.repository,
    required this.settings,
    required this.logger,
    required this.dispose,
    this.autostart,
    this.sync,
    this.resident,
    this.singleInstance,
  });

  final TodoRepository repository;
  final SettingsStore settings;
  final AppLogger logger;
  final AutostartService? autostart;
  final SyncService? sync;
  final ResidentService? resident;
  final SingleInstanceService? singleInstance;
  final Future<void> Function() dispose;
}
