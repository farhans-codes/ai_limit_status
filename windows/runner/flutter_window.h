#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>

#include <memory>

#include "win32_window.h"

class WindowsTaskbarStatus;
class WindowsNotificationSound;
class WindowsBrowserSession;
class WindowsSecureStore;

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Experimental taskbar overlay that displays live provider percentages.
  std::unique_ptr<WindowsTaskbarStatus> windows_taskbar_status_;

  // Plays the bundled warning chime for desktop notifications.
  std::unique_ptr<WindowsNotificationSound> windows_notification_sound_;

  // Reads an opt-in browser extension's in-memory provider sessions.
  std::unique_ptr<WindowsBrowserSession> windows_browser_session_;

  // DPAPI-backed protect/unprotect for small user secrets.
  std::unique_ptr<WindowsSecureStore> windows_secure_store_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
