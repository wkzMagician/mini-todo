import 'package:dartloom_resident/dartloom_resident.dart';
import 'package:dartloom_runtime/dartloom_runtime.dart';
import 'package:flutter/widgets.dart';

Future<void> configureResidentMenu() async {
  if (!Dartloom.contains<ResidentService>()) return;
  final resident = Dartloom.get<ResidentService>();
  final isChinese =
      WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'zh';

  await resident.configure(
    ResidentConfiguration(
      menu: [
        ResidentMenuItem.action(
          id: 'show',
          label: isChinese ? '显示 Mini Todo' : 'Show Mini Todo',
        ),
        const ResidentMenuItem.separator(),
        ResidentMenuItem.action(
          id: 'quit',
          label: isChinese ? '完全退出' : 'Quit completely',
        ),
      ],
      leftClick: ResidentClickAction.showMenu,
      rightClick: ResidentClickAction.showMenu,
      onMenuSelected: (id) async {
        if (id == 'show') await resident.restore();
      },
    ),
  );
}
