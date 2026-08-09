#include "flutter_window.h"

#include <optional>
#include <windows.h>
#include <windowsx.h>

#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  window_channel_ = std::make_unique<
      flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "mini_todo/window",
      &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "close") {
          PostMessage(GetHandle(), WM_CLOSE, 0, 0);
          result->Success();
          return;
        }

        if (call.method_name() == "hide") {
          ShowWindow(GetHandle(), SW_HIDE);
          result->Success();
          return;
        }

        if (call.method_name() == "startDragging") {
          ReleaseCapture();
          SendMessage(GetHandle(), WM_NCLBUTTONDOWN, HTCAPTION, 0);
          result->Success();
          return;
        }

        if (call.method_name() == "setCollapsed") {
          bool collapsed = false;
          if (call.arguments() &&
              std::holds_alternative<bool>(*call.arguments())) {
            collapsed = std::get<bool>(*call.arguments());
          }
          SetCollapsed(collapsed);
          result->Success();
          return;
        }

        result->NotImplemented();
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  window_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::SetCollapsed(bool collapsed) {
  HWND window = GetHandle();
  if (!window) {
    return;
  }

  RECT bounds;
  GetWindowRect(window, &bounds);
  const UINT dpi = GetDpiForWindow(window);
  const UINT effectiveDpi = dpi == 0 ? 96 : dpi;
  const int logicalHeight = collapsed ? 56 : 520;
  const int physicalHeight = MulDiv(logicalHeight, effectiveDpi, 96);

  SetWindowPos(
      window, HWND_TOPMOST, bounds.left, bounds.top,
      bounds.right - bounds.left, physicalHeight,
      SWP_NOACTIVATE | SWP_SHOWWINDOW);
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_NCHITTEST) {
    POINT point = {GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
    ScreenToClient(hwnd, &point);
    RECT client = GetClientArea();
    const UINT dpi = GetDpiForWindow(hwnd);
    const double scale = (dpi == 0 ? 96 : dpi) / 96.0;
    const LONG headerHeight = static_cast<LONG>(58 * scale);
    const LONG leftControls = static_cast<LONG>(56 * scale);
    const LONG rightControls = static_cast<LONG>(112 * scale);
    if (point.y >= 0 && point.y < headerHeight &&
        point.x > leftControls && point.x < client.right - rightControls) {
      return HTCAPTION;
    }
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
