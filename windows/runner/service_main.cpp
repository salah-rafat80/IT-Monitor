#include <flutter/dart_project.h>
#include <flutter/flutter_engine.h>
#include <windows.h>

#include <algorithm>
#include <chrono>
#include <iostream>
#include <string>
#include <vector>

#include "flutter/generated_plugin_registrant.h"
#include "utils.h"

static volatile bool g_running = true;

static BOOL WINAPI ConsoleCtrlHandler(DWORD signal) {
  if (signal == CTRL_C_EVENT || signal == CTRL_BREAK_EVENT ||
      signal == CTRL_CLOSE_EVENT || signal == CTRL_SHUTDOWN_EVENT) {
    g_running = false;
    ::PostQuitMessage(0);
    return TRUE;
  }
  return FALSE;
}

int main(int argc, char* argv[]) {
  // Set console control handler for graceful stop from supervisor or SCM
  ::SetConsoleCtrlHandler(ConsoleCtrlHandler, TRUE);

  // Initialize COM for plugins and sqlite
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // Configure DartProject
  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments = GetCommandLineArguments();
  // Ensure --service flag is present
  bool has_service_flag = false;
  for (const auto& arg : command_line_arguments) {
    if (arg == "--service") {
      has_service_flag = true;
      break;
    }
  }
  if (!has_service_flag) {
    command_line_arguments.push_back("--service");
  }

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  std::cout << "[it_monitoring_service] Launching headless FlutterEngine (no window/GUI)..." << std::endl;

  flutter::FlutterEngine engine(project);
  RegisterPlugins(&engine);

  if (!engine.Run()) {
    std::cerr << "[it_monitoring_service] FATAL: Failed to start FlutterEngine." << std::endl;
    ::CoUninitialize();
    return EXIT_FAILURE;
  }

  std::cout << "[it_monitoring_service] Headless FlutterEngine running successfully." << std::endl;

  // Process message loop without creating any GUI window, EGL context, or swap chains
  while (g_running) {
    std::chrono::nanoseconds wait_duration = engine.ProcessMessages();
    DWORD wait_ms = 100;
    if (wait_duration != std::chrono::nanoseconds::max()) {
      auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(wait_duration).count();
      wait_ms = static_cast<DWORD>(std::min<int64_t>(100, std::max<int64_t>(0, ms)));
    }

    ::MsgWaitForMultipleObjectsEx(0, nullptr, wait_ms, QS_ALLINPUT, MWMO_INPUTAVAILABLE);

    ::MSG msg;
    while (::PeekMessage(&msg, nullptr, 0, 0, PM_REMOVE)) {
      if (msg.message == WM_QUIT) {
        g_running = false;
        break;
      }
      ::TranslateMessage(&msg);
      ::DispatchMessage(&msg);
    }
  }

  std::cout << "[it_monitoring_service] Shutting down headless engine..." << std::endl;
  engine.ShutDown();
  ::CoUninitialize();
  return EXIT_SUCCESS;
}
