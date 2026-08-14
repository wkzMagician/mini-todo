// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Mini Todo';

  @override
  String get today => 'Today';

  @override
  String get thisWeek => 'This Week';

  @override
  String get thisMonth => 'This Month';

  @override
  String get thisYear => 'This Year';

  @override
  String taskSummary(Object period, int count) {
    return '$period · $count';
  }

  @override
  String noTasks(Object period) {
    return 'No $period tasks';
  }

  @override
  String get expand => 'Expand';

  @override
  String get collapse => 'Collapse';

  @override
  String get settings => 'Settings';

  @override
  String get closeApp => 'Hide window';

  @override
  String get autoStart => 'Launch at sign in';

  @override
  String get autoStartHint =>
      'Available when supported by the current platform';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get chinese => 'Chinese';

  @override
  String get newTask => 'New task';

  @override
  String get addTask => 'Add task';

  @override
  String get completeTask => 'Complete task';

  @override
  String get editTask => 'Edit task';

  @override
  String get saveEdit => 'Save edit';

  @override
  String get cancelEdit => 'Cancel edit';

  @override
  String get moreActions => 'More actions';

  @override
  String moveTo(Object period) {
    return 'Move to $period';
  }

  @override
  String taskCompleted(Object title) {
    return 'Completed “$title”';
  }

  @override
  String get undo => 'Undo';

  @override
  String get editTaskHint => 'Click to edit task';

  @override
  String get loading => 'Loading tasks';

  @override
  String get sync => 'Sync';

  @override
  String get syncWebDavUrl => 'WebDAV URL';

  @override
  String get syncWebDavUsername => 'Username';

  @override
  String get syncWebDavPassword => 'Password';

  @override
  String get syncStoredPasswordHint =>
      'Saved securely. Select the field to replace it.';

  @override
  String get saveSync => 'Save sync settings';

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncNotConfigured => 'Configure WebDAV first';

  @override
  String get syncSucceeded => 'Sync complete';

  @override
  String get syncConflicted => 'Sync has conflicts';

  @override
  String get syncFailed => 'Sync failed';
}
