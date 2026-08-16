import 'package:dartloom_autostart/dartloom_autostart.dart';
import 'package:dartloom_logging/dartloom_logging.dart';
import 'package:dartloom_settings/dartloom_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_todo/app/app.dart';
import 'package:mini_todo/features/todos/data/todo_repository.dart';

void main() {
  MiniTodoApp buildTestApp() => MiniTodoApp(
    repository: MemoryTodoRepository(),
    settings: MemorySettingsStore(),
    autostart: MemoryAutostartService(),
    logger: MemoryLogger(),
    initialLocale: const Locale('zh'),
  );

  testWidgets('shows the Mini Todo app shell', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Mini Todo'), findsOneWidget);
    expect(find.text('今天'), findsWidgets);
    expect(find.text('今天暂无任务'), findsOneWidget);
  });

  testWidgets('creates and completes a task', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Write a test');
    await tester.tap(find.byTooltip('添加任务'));
    await tester.pumpAndSettle();

    expect(find.text('Write a test'), findsOneWidget);
    await tester.tap(find.byTooltip('完成任务'));
    await tester.pumpAndSettle();
    expect(find.text('Write a test'), findsNothing);
  });

  testWidgets('runs without desktop-only capabilities', (tester) async {
    await tester.pumpWidget(
      MiniTodoApp(
        repository: MemoryTodoRepository(),
        settings: MemorySettingsStore(),
        logger: MemoryLogger(),
        initialLocale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mini Todo'), findsOneWidget);
    expect(find.byTooltip('Close app'), findsNothing);
  });

  testWidgets('opens settings as a dedicated full-page view', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('今天'), findsNothing);
    expect(find.byTooltip('取消编辑'), findsOneWidget);

    await tester.tap(find.byTooltip('取消编辑'));
    await tester.pumpAndSettle();

    expect(find.text('Mini Todo'), findsOneWidget);
    expect(find.text('今天'), findsWidgets);
  });
}
