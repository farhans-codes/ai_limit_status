#ifndef RUNNER_WINDOWS_TASKBAR_STATUS_H_
#define RUNNER_WINDOWS_TASKBAR_STATUS_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>
#include <optional>
#include <string>

class WindowsTaskbarStatus {
 public:
  WindowsTaskbarStatus(flutter::BinaryMessenger* messenger, HWND host_window);
  ~WindowsTaskbarStatus();

  std::optional<LRESULT> HandleMessage(UINT message,
                                       WPARAM wparam,
                                       LPARAM lparam);
  void Destroy();

 private:
  static constexpr wchar_t kOverlayClassName[] =
      L"AI_LIMIT_STATUS_TASKBAR_OVERLAY";

  static LRESULT CALLBACK OverlayWindowProc(HWND window,
                                             UINT message,
                                             WPARAM wparam,
                                             LPARAM lparam);

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void CreateOverlayIfNeeded();
  void UpdateOverlay();
  void PositionOverlay();
  bool RenderLayeredOverlay(int x, int y, int width, int height);
  void PaintOverlay(HDC dc, const RECT& bounds);
  void PaintProvider(HDC dc,
                     const RECT& bounds,
                     const std::wstring& value,
                     bool is_claude) const;
  void PaintProviderMark(HDC dc,
                         const RECT& bounds,
                         bool is_claude) const;
  void ShowContextMenu();
  void InvokeDart(const std::string& method);
  bool IsPointerOverTaskbarUi() const;

  std::optional<std::wstring> ReadOptionalValue(
      const flutter::EncodableMap& arguments,
      const char* key) const;

  HWND host_window_;
  HWND overlay_window_ = nullptr;
  UINT taskbar_created_message_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::optional<std::wstring> codex_value_;
  std::optional<std::wstring> claude_value_;
  std::wstring tooltip_;
  std::wstring open_label_;
  std::wstring refresh_label_;
  std::wstring quit_label_;
  bool initialized_ = false;
};

#endif  // RUNNER_WINDOWS_TASKBAR_STATUS_H_
