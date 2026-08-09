// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Mini Todo';

  @override
  String get today => '今天';

  @override
  String get thisWeek => '本周';

  @override
  String get thisMonth => '本月';

  @override
  String get thisYear => '今年';

  @override
  String taskSummary(Object period, int count) {
    return '$period · $count';
  }

  @override
  String noTasks(Object period) {
    return '$period暂无任务';
  }

  @override
  String get expand => '展开';

  @override
  String get collapse => '折叠';

  @override
  String get settings => '设置';

  @override
  String get closeApp => '隐藏窗口';

  @override
  String get autoStart => '开机自启动';

  @override
  String get autoStartHint => '当前平台支持时生效';

  @override
  String get language => '语言';

  @override
  String get english => 'English';

  @override
  String get chinese => '中文';

  @override
  String get newTask => '新任务';

  @override
  String get addTask => '添加任务';

  @override
  String get completeTask => '完成任务';

  @override
  String get editTask => '编辑任务';

  @override
  String get saveEdit => '保存编辑';

  @override
  String get cancelEdit => '取消编辑';

  @override
  String get moreActions => '更多操作';

  @override
  String moveTo(Object period) {
    return '移动到$period';
  }

  @override
  String taskCompleted(Object title) {
    return '已完成“$title”';
  }

  @override
  String get undo => '撤销';

  @override
  String get editTaskHint => '点击编辑任务';

  @override
  String get loading => '正在读取任务';

  @override
  String get sync => '同步';

  @override
  String get syncWebDavUrl => 'WebDAV 地址';

  @override
  String get syncWebDavRootPath => '远程目录';

  @override
  String get syncWebDavUsername => '用户名';

  @override
  String get syncWebDavPassword => '密码';

  @override
  String get saveSync => '保存同步设置';

  @override
  String get syncNow => '立即同步';

  @override
  String get syncNotConfigured => '请先配置 WebDAV';

  @override
  String get syncSucceeded => '同步完成';

  @override
  String get syncConflicted => '同步存在冲突';

  @override
  String get syncFailed => '同步失败';
}
