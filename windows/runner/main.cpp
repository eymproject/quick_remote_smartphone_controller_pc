#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

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

  // Enable drag and drop when running with elevated privileges
  // Use ChangeWindowMessageFilter and ChangeWindowMessageFilterEx to allow drag and drop messages
  typedef BOOL (WINAPI *ChangeWindowMessageFilterProc)(UINT message, DWORD dwFlag);
  typedef BOOL (WINAPI *ChangeWindowMessageFilterExProc)(HWND hwnd, UINT message, DWORD action, void* pChangeFilterStruct);
  
  HMODULE user32 = GetModuleHandle(L"user32.dll");
  if (user32) {
    ChangeWindowMessageFilterProc changeWindowMessageFilter = 
      (ChangeWindowMessageFilterProc)GetProcAddress(user32, "ChangeWindowMessageFilter");
    ChangeWindowMessageFilterExProc changeWindowMessageFilterEx = 
      (ChangeWindowMessageFilterExProc)GetProcAddress(user32, "ChangeWindowMessageFilterEx");
    
    if (changeWindowMessageFilter) {
      // Allow drag and drop related messages
      changeWindowMessageFilter(WM_DROPFILES, 1); // MSGFLT_ADD
      changeWindowMessageFilter(WM_COPYDATA, 1);
      changeWindowMessageFilter(0x0049, 1); // WM_COPYGLOBALDATA
      changeWindowMessageFilter(0x004A, 1); // WM_COPYDATA
      changeWindowMessageFilter(0x004E, 1); // WM_NOTIFY
    }
    
    // Also try the newer API if available
    if (changeWindowMessageFilterEx) {
      changeWindowMessageFilterEx(NULL, WM_DROPFILES, 1, NULL); // MSGFLT_ALLOW
      changeWindowMessageFilterEx(NULL, WM_COPYDATA, 1, NULL);
      changeWindowMessageFilterEx(NULL, 0x0049, 1, NULL); // WM_COPYGLOBALDATA
    }
  }

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"qrsc_pc", origin, size)) {
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
