#ifndef RUNNER_WINDOWS_STATUS_TRAY_H_
#define RUNNER_WINDOWS_STATUS_TRAY_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <array>
#include <memory>
#include <optional>
#include <string>

class WindowsStatusTray {
 public:
  WindowsStatusTray(flutter::BinaryMessenger* messenger, HWND window);
  ~WindowsStatusTray();

  std::optional<LRESULT> HandleMessage(UINT message,
                                       WPARAM wparam,
                                       LPARAM lparam);
  void Destroy();

 private:
  struct IconState {
    bool visible = false;
    HICON icon = nullptr;
  };

  static constexpr UINT kStatusIconId = 1;
  static constexpr UINT kCallbackMessage = WM_APP + 41;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void UpdateIcons();
  void ApplyIcon(UINT id,
                 const std::wstring& value,
                 COLORREF background,
                 const std::wstring& tooltip);
  void ApplyCombinedIcon(UINT id,
                         const std::wstring& claude_value,
                         const std::wstring& codex_value,
                         const std::wstring& tooltip);
  void SetIcon(UINT id, HICON icon, const std::wstring& tooltip);
  void RemoveIcon(UINT id);
  void ShowContextMenu();
  void InvokeDart(const std::string& method);
  HICON CreateStatusIcon(const std::wstring& value, COLORREF background) const;
  HICON CreateCombinedStatusIcon(const std::wstring& claude_value,
                                 const std::wstring& codex_value) const;

  IconState& StateFor(UINT id);
  std::optional<std::wstring> ReadOptionalValue(
      const flutter::EncodableMap& arguments,
      const char* key) const;

  HWND window_;
  UINT taskbar_created_message_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::array<IconState, 1> icon_states_{};
  std::optional<std::wstring> codex_value_;
  std::optional<std::wstring> claude_value_;
  std::wstring tooltip_;
  std::wstring open_label_;
  std::wstring refresh_label_;
  std::wstring quit_label_;
  bool initialized_ = false;
};

#endif  // RUNNER_WINDOWS_STATUS_TRAY_H_
