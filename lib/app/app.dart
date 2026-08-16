import 'package:dartloom_autostart/dartloom_autostart.dart';
import 'package:dartloom_logging/dartloom_logging.dart';
import 'package:dartloom_settings/dartloom_settings.dart';
import 'package:dartloom_sync/dartloom_sync.dart';
import 'package:flutter/material.dart';

import '../features/todos/data/todo_repository.dart';
import '../features/todos/presentation/todo_home_page.dart';
import '../l10n/app_localizations.dart';

class MiniTodoApp extends StatefulWidget {
  const MiniTodoApp({
    super.key,
    required this.repository,
    required this.settings,
    required this.logger,
    this.autostart,
    this.syncService,
    this.initialLocale,
  });

  final TodoRepository repository;
  final SettingsStore settings;
  final AutostartService? autostart;
  final AppLogger logger;
  final SyncService? syncService;
  final Locale? initialLocale;

  @override
  State<MiniTodoApp> createState() => _MiniTodoAppState();
}

class _MiniTodoAppState extends State<MiniTodoApp> {
  static const _localeKey = 'app.locale';
  late final SettingsStore _settings = widget.settings;
  late Locale _locale;

  @override
  void initState() {
    super.initState();
    _locale = widget.initialLocale ?? _platformLocale();
    _restoreLocale();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Mini Todo',
    onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
    debugShowCheckedModeBanner: false,
    locale: _locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff0f766e)),
      fontFamily: 'Segoe UI',
      scaffoldBackgroundColor: const Color(0xffeef3f6),
      inputDecorationTheme: const InputDecorationTheme(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          borderSide: BorderSide(color: Color(0xffcbd7df)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          borderSide: BorderSide(color: Color(0xffcbd7df)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          borderSide: BorderSide(color: Color(0xff7fb8b2)),
        ),
      ),
    ),
    home: TodoHomePage(
      repository: widget.repository,
      settings: _settings,
      autostart: widget.autostart,
      logger: widget.logger,
      syncService: widget.syncService,
      locale: _locale,
      onLocaleChanged: _setLocale,
    ),
  );

  Locale _platformLocale() {
    final languageCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return languageCode == 'zh' ? const Locale('zh') : const Locale('en');
  }

  Future<void> _restoreLocale() async {
    if (widget.initialLocale != null) return;
    final languageCode = await _settings.read(_localeKey) as String?;
    if (!mounted || languageCode == null) return;
    setState(() {
      _locale = languageCode == 'zh' ? const Locale('zh') : const Locale('en');
    });
  }

  Future<void> _setLocale(Locale locale) async {
    await _settings.write(_localeKey, locale.languageCode);
    if (mounted) setState(() => _locale = locale);
  }
}
