# Mini Todo

一个轻量、跨平台的待办事项应用。支持按「今天 / 本周 / 本月 / 今年」整理任务，并可通过 WebDAV 在设备之间同步。

## 功能特性

- **多周期视图**：任务按 今天、本周、本月、今年 分类，随时切换查看。
- **便捷操作**：快速添加任务、点击编辑、滑动或点击完成，误删可撤销。
- **拖拽排序**：在同一个周期内自由调整任务顺序。
- **开机自启动**：可选随系统启动，随时快速记下想法。
- **系统托盘**：关闭窗口后驻留托盘，不打扰、不丢失。
- **多语言**：内置中文与 English，可在设置中切换。
- **跨平台**：支持 Android、Windows、macOS、Linux。

## WebDAV 同步

在设置中填入 WebDAV 地址、用户名和密码即可开启同步，之后设备间的任务会自动保持一致，支持手动触发同步。

> 同步数据存放于 WebDAV 的 `MiniTodo` 数据集中，请勿手动修改其中的文件。

## 支持平台

| 平台 | 支持情况 |
| --- | --- |
| Windows | ✅ |
| macOS | ✅ |
| Linux | ✅ |
| Android | ✅ |

> 开机自启动和系统托盘在部分平台上可能不可用，界面会自动隐藏相关选项。

## 开发

```bash
flutter pub get
flutter run -d windows
flutter run -d android
```

提交前运行：

```bash
dart format .
flutter analyze
flutter test
```
