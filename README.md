# Mini Todo

Mini Todo 是一个 Flutter 待办应用，通过 Dartloom 管理设置、目录存储和 WebDAV 同步。

## WebDAV 同步

在设置中填写 WebDAV 地址、用户名和密码。远端数据集固定为 `MiniTodo`，不能从界面改成任意目录。

本地和远端采用相同的平面文件布局：

```text
MiniTodo/
├── .mini-todo.json
├── todo-<id>
└── todo-<id>
```

同步状态和删除日志存放在数据集外部，不会上传。升级时会把旧的本地聚合 JSON 导出成独立文件，并将远端 `MiniTodo/json/todo-*` 幂等复制到 `MiniTodo/todo-*`；旧文件不会自动删除。

所有平台的前台轮询间隔为 5 分钟。Android 系统后台任务受平台最小间隔限制，仍为 15 分钟。

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
