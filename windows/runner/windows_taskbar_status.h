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

  // The details window is shown, hidden, and positioned natively, from the
  // same thread and input event that clicked the overlay, so Windows still
  // grants this process foreground rights and no DPI round trip through
  // Dart is needed.
  bool IsPopoverVisible() const;
  void ShowPopover();
  void HidePopover();
  void TogglePopover();
  RECT PopoverBoundsAnchoredToTaskbar(int width, int height) const;
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
  // Last overlay placement and content that were actually rendered, so the
  // one-second reposition timer is a no-op unless something changed and
  // never re-asserts HWND_TOPMOST above the open details window.
  RECT last_overlay_bounds_{};
  std::wstring last_rendered_signature_;
  bool overlay_rendered_ = false;
};

#endif  // RUNNER_WINDOWS_TASKBAR_STATUS_H_
