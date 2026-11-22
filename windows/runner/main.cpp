#include <flutter/dart_project.h>
#include <flutter/flutter_engine.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <chrono>
#include <string>
#include <vector>

#include "flutter/generated_plugin_registrant.h"
#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  bool is_service_mode = false;
  for (const auto& arg : command_line_arguments) {
    if (arg == "--service" || arg == "--headless") {
      is_service_mode = true;
      break;
    }
  }

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  if (is_service_mode) {
    // Headless Windows service execution: DO NOT create GUI window or EGL surface
    flutter::FlutterEngine engine(project);
    RegisterPlugins(&engine);
    if (!engine.Run()) {
      ::CoUninitialize();
      return EXIT_FAILURE;
    }
    ::MSG msg;
    while (::GetMessage(&msg, nullptr, 0, 0)) {
      if (msg.message == WM_QUIT) break;
      ::TranslateMessage(&msg);
      ::DispatchMessage(&msg);
      engine.ProcessMessages();
    }
    engine.ShutDown();
    ::CoUninitialize();
    return EXIT_SUCCESS;
  }

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"IT Network Monitor - Indomie", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
