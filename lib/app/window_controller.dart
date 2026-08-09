import 'package:flutter/services.dart';

class DesktopWindowController {
  static const _channel = MethodChannel('mini_todo/window');

  Future<void> setCollapsed(bool collapsed) async {
    try {
      await _channel.invokeMethod<void>('setCollapsed', collapsed);
    } on MissingPluginException {
      // Android, macOS, and widget tests can use the Flutter layout fallback.
    }
  }

  Future<void> close() async {
    try {
      await _channel.invokeMethod<void>('close');
    } on MissingPluginException {
      await SystemNavigator.pop();
    }
  }

  Future<void> hide() async {
    try {
      await _channel.invokeMethod<void>('hide');
    } on MissingPluginException {
      // Widget tests and non-Windows hosts have no native window to hide.
    }
  }

  Future<void> startDragging() async {
    try {
      await _channel.invokeMethod<void>('startDragging');
    } on MissingPluginException {
      // Dragging is implemented by the Windows runner only.
    }
  }
}
