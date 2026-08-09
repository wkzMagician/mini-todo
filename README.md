# Mini Todo

Mini Todo 是一个 Windows 桌面待办应用，使用 Flutter 重构，并通过
Dartloom 管理设置、存储和同步能力。

## 功能

- 创建、编辑、完成和删除待办事项
- 常驻系统托盘，可快速恢复或完全退出应用
- 可选 WebDAV 多设备同步；每次打开应用会自动同步一次，也可手动同步
- 待办数据保存在本机；同步未配置或失败时不会清除本地数据

## WebDAV 同步

打开应用的“设置”，填写以下信息后点击“保存”，再点击“立即同步”：

- WebDAV 地址：服务端地址，例如 `https://dav.example.com/remote.php/dav/files/your-name/`
- 远程文件夹：用于保存 Mini Todo 同步数据的目录，例如 `MiniTodo`
- 用户名和密码：该 WebDAV 服务的登录凭据

首次同步会在远程目录为每条待办创建独立的数据文件。多个设备请使用相同的服务地址、目录和账号。

## 开发

```bash
flutter pub get
flutter run -d windows
```

提交前请运行：

```bash
dart format .
flutter analyze
flutter test
```
