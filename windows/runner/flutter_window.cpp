#include "flutter_window.h"

#include <optional>

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

  // Setup window management method channel for borderless/frameless fullscreen (Wall Display Kiosk)
  HWND hwnd = GetHandle();
  window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "it_network_monitor/window",
          &flutter::StandardMethodCodec::GetInstance());

  window_channel_->SetMethodCallHandler(
      [hwnd](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        static RECT prev_rect = {};
        static DWORD prev_style = 0;
        static DWORD prev_ex_style = 0;
        static bool is_fullscreen = false;

        const std::string& method = call.method_name();
        if (method == "enterFullScreen") {
          if (!is_fullscreen) {
            prev_style = GetWindowLong(hwnd, GWL_STYLE);
            prev_ex_style = GetWindowLong(hwnd, GWL_EXSTYLE);
            GetWindowRect(hwnd, &prev_rect);

            HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
            MONITORINFO mi = { sizeof(mi) };
            if (GetMonitorInfo(monitor, &mi)) {
              SetWindowLong(hwnd, GWL_STYLE,
                            prev_style & ~(WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SYSMENU));
              SetWindowLong(hwnd, GWL_EXSTYLE,
                            prev_ex_style & ~(WS_EX_DLGMODALFRAME | WS_EX_CLIENTEDGE | WS_EX_STATICEDGE | WS_EX_WINDOWEDGE));

              SetWindowPos(hwnd, HWND_TOP,
                           mi.rcMonitor.left,
                           mi.rcMonitor.top,
                           mi.rcMonitor.right - mi.rcMonitor.left,
                           mi.rcMonitor.bottom - mi.rcMonitor.top,
                           SWP_NOOWNERZORDER | SWP_FRAMECHANGED | SWP_SHOWWINDOW);
              is_fullscreen = true;
            }
          }
          result->Success(flutter::EncodableValue(true));
        } else if (method == "exitFullScreen") {
          if (is_fullscreen) {
            SetWindowLong(hwnd, GWL_STYLE, prev_style);
            SetWindowLong(hwnd, GWL_EXSTYLE, prev_ex_style);
            SetWindowPos(hwnd, HWND_NOTOPMOST,
                         prev_rect.left,
                         prev_rect.top,
                         prev_rect.right - prev_rect.left,
                         prev_rect.bottom - prev_rect.top,
                         SWP_NOOWNERZORDER | SWP_FRAMECHANGED | SWP_SHOWWINDOW);
            is_fullscreen = false;
          }
          result->Success(flutter::EncodableValue(true));
        } else if (method == "toggleFullScreen") {
          if (is_fullscreen) {
            SetWindowLong(hwnd, GWL_STYLE, prev_style);
            SetWindowLong(hwnd, GWL_EXSTYLE, prev_ex_style);
            SetWindowPos(hwnd, HWND_NOTOPMOST,
                         prev_rect.left,
                         prev_rect.top,
                         prev_rect.right - prev_rect.left,
                         prev_rect.bottom - prev_rect.top,
                         SWP_NOOWNERZORDER | SWP_FRAMECHANGED | SWP_SHOWWINDOW);
            is_fullscreen = false;
          } else {
            prev_style = GetWindowLong(hwnd, GWL_STYLE);
            prev_ex_style = GetWindowLong(hwnd, GWL_EXSTYLE);
            GetWindowRect(hwnd, &prev_rect);

            HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
            MONITORINFO mi = { sizeof(mi) };
            if (GetMonitorInfo(monitor, &mi)) {
              SetWindowLong(hwnd, GWL_STYLE,
                            prev_style & ~(WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SYSMENU));
              SetWindowLong(hwnd, GWL_EXSTYLE,
                            prev_ex_style & ~(WS_EX_DLGMODALFRAME | WS_EX_CLIENTEDGE | WS_EX_STATICEDGE | WS_EX_WINDOWEDGE));

              SetWindowPos(hwnd, HWND_TOP,
                           mi.rcMonitor.left,
                           mi.rcMonitor.top,
                           mi.rcMonitor.right - mi.rcMonitor.left,
                           mi.rcMonitor.bottom - mi.rcMonitor.top,
                           SWP_NOOWNERZORDER | SWP_FRAMECHANGED | SWP_SHOWWINDOW);
              is_fullscreen = true;
            }
          }
          result->Success(flutter::EncodableValue(is_fullscreen));
        } else if (method == "isFullScreen") {
          result->Success(flutter::EncodableValue(is_fullscreen));
        } else {
          result->NotImplemented();
        }
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
  if (window_channel_) {
    window_channel_ = nullptr;
  }
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
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
