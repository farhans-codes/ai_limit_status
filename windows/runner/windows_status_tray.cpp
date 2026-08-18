#include "windows_status_tray.h"

#include <flutter/standard_method_codec.h>
#include <shellapi.h>
#include <strsafe.h>

#include <algorithm>

namespace {

constexpr UINT kOpenCommand = 1001;
constexpr UINT kRefreshCommand = 1002;
constexpr UINT kQuitCommand = 1003;
constexpr int kIconSize = 32;

constexpr COLORREF kCodexColor = RGB(37, 99, 235);
constexpr COLORREF kClaudeColor = RGB(198, 92, 59);
constexpr COLORREF kGenericColor = RGB(75, 85, 99);

const flutter::EncodableValue* ValueOrNull(
    const flutter::EncodableMap& arguments,
    const char* key) {
  const auto iterator = arguments.find(flutter::EncodableValue(key));
  return iterator == arguments.end() ? nullptr : &iterator->second;
}

std::wstring Utf8ToWide(const std::string& value) {
  if (value.empty()) {
    return std::wstring();
  }
  const int length = MultiByteToWideChar(
      CP_UTF8, 0, value.c_str(), static_cast<int>(value.size()), nullptr, 0);
  if (length <= 0) {
    return std::wstring();
  }
  std::wstring output(length, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value.c_str(),
                      static_cast<int>(value.size()), output.data(), length);
  return output;
}

std::wstring RequiredString(const flutter::EncodableMap& arguments,
                            const char* key) {
  const auto* value = ValueOrNull(arguments, key);
  const auto* text = value == nullptr ? nullptr : std::get_if<std::string>(value);
  return text == nullptr ? std::wstring() : Utf8ToWide(*text);
}

std::wstring DisplayValue(const std::wstring& value) {
  std::wstring display = value;
  display.erase(std::remove(display.begin(), display.end(), L'%'), display.end());
  if (display.empty()) {
    return L"--";
  }
  if (display.size() > 3) {
    display.resize(3);
  }
  return display;
}

void DrawStatusText(HDC device_context,
                    const std::wstring& value,
                    RECT bounds,
                    int font_height,
                    int font_width = 0) {
  HFONT font = CreateFontW(-font_height, font_width, 0, 0, FW_BOLD, FALSE,
                           FALSE, FALSE, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS,
                           CLIP_DEFAULT_PRECIS, ANTIALIASED_QUALITY,
                           DEFAULT_PITCH, L"Segoe UI");
  if (font == nullptr) {
    return;
  }

  const HGDIOBJ old_font = SelectObject(device_context, font);
  SetBkMode(device_context, TRANSPARENT);
  SetTextColor(device_context, RGB(255, 255, 255));
  DrawTextW(device_context, value.c_str(), -1, &bounds,
            DT_CENTER | DT_VCENTER | DT_SINGLELINE | DT_NOPREFIX);
  SelectObject(device_context, old_font);
  DeleteObject(font);
}

}  // namespace

WindowsStatusTray::WindowsStatusTray(flutter::BinaryMessenger* messenger,
                                     HWND window)
    : window_(window),
      taskbar_created_message_(RegisterWindowMessageW(L"TaskbarCreated")),
      channel_(std::make_unique<
               flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "com.ailimitstatus/windows_status_tray",
          &flutter::StandardMethodCodec::GetInstance())) {
  channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleMethodCall(call, std::move(result));
      });
}

WindowsStatusTray::~WindowsStatusTray() {
  Destroy();
}

void WindowsStatusTray::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto* arguments =
      std::get_if<flutter::EncodableMap>(method_call.arguments());
  if (method_call.method_name() == "initialize" && arguments != nullptr) {
    open_label_ = RequiredString(*arguments, "openLabel");
    refresh_label_ = RequiredString(*arguments, "refreshLabel");
    quit_label_ = RequiredString(*arguments, "quitLabel");
    tooltip_ = RequiredString(*arguments, "tooltip");
    initialized_ = true;
    UpdateIcons();
    result->Success();
    return;
  }
  if (method_call.method_name() == "update" && arguments != nullptr) {
    codex_value_ = ReadOptionalValue(*arguments, "codexValue");
    claude_value_ = ReadOptionalValue(*arguments, "claudeValue");
    tooltip_ = RequiredString(*arguments, "tooltip");
    UpdateIcons();
    result->Success();
    return;
  }
  if (method_call.method_name() == "destroy") {
    Destroy();
    result->Success();
    return;
  }
  result->NotImplemented();
}

std::optional<LRESULT> WindowsStatusTray::HandleMessage(UINT message,
                                                        WPARAM wparam,
                                                        LPARAM lparam) {
  if (message == taskbar_created_message_ && initialized_) {
    for (auto& state : icon_states_) {
      state.visible = false;
    }
    UpdateIcons();
    return 0;
  }
  if (message != kCallbackMessage) {
    return std::nullopt;
  }

  const UINT icon_id = static_cast<UINT>(wparam);
  if (icon_id != kStatusIconId) {
    return std::nullopt;
  }
  switch (static_cast<UINT>(lparam)) {
    case WM_LBUTTONUP:
      InvokeDart("toggle");
      return 0;
    case WM_RBUTTONUP:
      ShowContextMenu();
      return 0;
    default:
      return 0;
  }
}

void WindowsStatusTray::UpdateIcons() {
  if (!initialized_) {
    return;
  }

  if (claude_value_.has_value() && codex_value_.has_value()) {
    ApplyCombinedIcon(kStatusIconId, DisplayValue(*claude_value_),
                      DisplayValue(*codex_value_), tooltip_);
  } else if (claude_value_.has_value()) {
    ApplyIcon(kStatusIconId, DisplayValue(*claude_value_), kClaudeColor,
              tooltip_);
  } else if (codex_value_.has_value()) {
    ApplyIcon(kStatusIconId, DisplayValue(*codex_value_), kCodexColor,
              tooltip_);
  } else {
    ApplyIcon(kStatusIconId, L"AI", kGenericColor, tooltip_);
  }
}

void WindowsStatusTray::ApplyIcon(UINT id,
                                  const std::wstring& value,
                                  COLORREF background,
                                  const std::wstring& tooltip) {
  HICON new_icon = CreateStatusIcon(value, background);
  if (new_icon == nullptr) {
    return;
  }

  SetIcon(id, new_icon, tooltip);
}

void WindowsStatusTray::ApplyCombinedIcon(
    UINT id,
    const std::wstring& claude_value,
    const std::wstring& codex_value,
    const std::wstring& tooltip) {
  HICON new_icon = CreateCombinedStatusIcon(claude_value, codex_value);
  if (new_icon == nullptr) {
    return;
  }

  SetIcon(id, new_icon, tooltip);
}

void WindowsStatusTray::SetIcon(UINT id,
                                HICON new_icon,
                                const std::wstring& tooltip) {
  IconState& state = StateFor(id);
  NOTIFYICONDATAW data{};
  data.cbSize = sizeof(data);
  data.hWnd = window_;
  data.uID = id;
  data.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
  data.uCallbackMessage = kCallbackMessage;
  data.hIcon = new_icon;
  StringCchCopyW(data.szTip, ARRAYSIZE(data.szTip), tooltip.c_str());

  const DWORD operation = state.visible ? NIM_MODIFY : NIM_ADD;
  if (Shell_NotifyIconW(operation, &data)) {
    if (state.icon != nullptr) {
      DestroyIcon(state.icon);
    }
    state.icon = new_icon;
    state.visible = true;
  } else {
    DestroyIcon(new_icon);
  }
}

void WindowsStatusTray::RemoveIcon(UINT id) {
  IconState& state = StateFor(id);
  if (state.visible) {
    NOTIFYICONDATAW data{};
    data.cbSize = sizeof(data);
    data.hWnd = window_;
    data.uID = id;
    Shell_NotifyIconW(NIM_DELETE, &data);
    state.visible = false;
  }
  if (state.icon != nullptr) {
    DestroyIcon(state.icon);
    state.icon = nullptr;
  }
}

void WindowsStatusTray::ShowContextMenu() {
  HMENU menu = CreatePopupMenu();
  if (menu == nullptr) {
    return;
  }
  AppendMenuW(menu, MF_STRING, kOpenCommand, open_label_.c_str());
  AppendMenuW(menu, MF_STRING, kRefreshCommand, refresh_label_.c_str());
  AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenuW(menu, MF_STRING, kQuitCommand, quit_label_.c_str());

  POINT cursor{};
  GetCursorPos(&cursor);
  SetForegroundWindow(window_);
  const UINT command = TrackPopupMenu(
      menu, TPM_RETURNCMD | TPM_NONOTIFY | TPM_RIGHTBUTTON, cursor.x, cursor.y,
      0, window_, nullptr);
  DestroyMenu(menu);
  PostMessageW(window_, WM_NULL, 0, 0);

  switch (command) {
    case kOpenCommand:
      InvokeDart("show");
      break;
    case kRefreshCommand:
      InvokeDart("refresh");
      break;
    case kQuitCommand:
      InvokeDart("quit");
      break;
    default:
      break;
  }
}

void WindowsStatusTray::InvokeDart(const std::string& method) {
  channel_->InvokeMethod(
      method, std::make_unique<flutter::EncodableValue>());
}

HICON WindowsStatusTray::CreateStatusIcon(const std::wstring& value,
                                          COLORREF background) const {
  HDC screen_dc = GetDC(nullptr);
  if (screen_dc == nullptr) {
    return nullptr;
  }
  HDC color_dc = CreateCompatibleDC(screen_dc);
  HDC mask_dc = CreateCompatibleDC(screen_dc);
  HBITMAP color_bitmap =
      CreateCompatibleBitmap(screen_dc, kIconSize, kIconSize);
  HBITMAP mask_bitmap = CreateBitmap(kIconSize, kIconSize, 1, 1, nullptr);
  ReleaseDC(nullptr, screen_dc);

  if (color_dc == nullptr || mask_dc == nullptr || color_bitmap == nullptr ||
      mask_bitmap == nullptr) {
    if (color_dc != nullptr) DeleteDC(color_dc);
    if (mask_dc != nullptr) DeleteDC(mask_dc);
    if (color_bitmap != nullptr) DeleteObject(color_bitmap);
    if (mask_bitmap != nullptr) DeleteObject(mask_bitmap);
    return nullptr;
  }

  const HGDIOBJ old_color_bitmap = SelectObject(color_dc, color_bitmap);
  const HGDIOBJ old_mask_bitmap = SelectObject(mask_dc, mask_bitmap);
  RECT bounds{0, 0, kIconSize, kIconSize};

  HBRUSH transparent_brush = CreateSolidBrush(RGB(0, 0, 0));
  FillRect(color_dc, &bounds, transparent_brush);
  DeleteObject(transparent_brush);

  HBRUSH background_brush = CreateSolidBrush(background);
  HPEN background_pen = CreatePen(PS_SOLID, 1, background);
  const HGDIOBJ old_brush = SelectObject(color_dc, background_brush);
  const HGDIOBJ old_pen = SelectObject(color_dc, background_pen);
  RoundRect(color_dc, 1, 1, kIconSize - 1, kIconSize - 1, 9, 9);

  DrawStatusText(color_dc, value, bounds, value.size() >= 3 ? 16 : 20);

  SelectObject(color_dc, old_pen);
  SelectObject(color_dc, old_brush);
  DeleteObject(background_pen);
  DeleteObject(background_brush);

  PatBlt(mask_dc, 0, 0, kIconSize, kIconSize, WHITENESS);
  HGDIOBJ mask_brush = GetStockObject(BLACK_BRUSH);
  HGDIOBJ mask_pen = GetStockObject(BLACK_PEN);
  const HGDIOBJ old_mask_brush = SelectObject(mask_dc, mask_brush);
  const HGDIOBJ old_mask_pen = SelectObject(mask_dc, mask_pen);
  RoundRect(mask_dc, 1, 1, kIconSize - 1, kIconSize - 1, 9, 9);
  SelectObject(mask_dc, old_mask_pen);
  SelectObject(mask_dc, old_mask_brush);

  SelectObject(color_dc, old_color_bitmap);
  SelectObject(mask_dc, old_mask_bitmap);
  DeleteDC(color_dc);
  DeleteDC(mask_dc);

  ICONINFO icon_info{};
  icon_info.fIcon = TRUE;
  icon_info.hbmColor = color_bitmap;
  icon_info.hbmMask = mask_bitmap;
  HICON icon = CreateIconIndirect(&icon_info);
  DeleteObject(color_bitmap);
  DeleteObject(mask_bitmap);
  return icon;
}

HICON WindowsStatusTray::CreateCombinedStatusIcon(
    const std::wstring& claude_value,
    const std::wstring& codex_value) const {
  HDC screen_dc = GetDC(nullptr);
  if (screen_dc == nullptr) {
    return nullptr;
  }
  HDC color_dc = CreateCompatibleDC(screen_dc);
  HDC mask_dc = CreateCompatibleDC(screen_dc);
  HBITMAP color_bitmap =
      CreateCompatibleBitmap(screen_dc, kIconSize, kIconSize);
  HBITMAP mask_bitmap = CreateBitmap(kIconSize, kIconSize, 1, 1, nullptr);
  ReleaseDC(nullptr, screen_dc);

  if (color_dc == nullptr || mask_dc == nullptr || color_bitmap == nullptr ||
      mask_bitmap == nullptr) {
    if (color_dc != nullptr) DeleteDC(color_dc);
    if (mask_dc != nullptr) DeleteDC(mask_dc);
    if (color_bitmap != nullptr) DeleteObject(color_bitmap);
    if (mask_bitmap != nullptr) DeleteObject(mask_bitmap);
    return nullptr;
  }

  const HGDIOBJ old_color_bitmap = SelectObject(color_dc, color_bitmap);
  const HGDIOBJ old_mask_bitmap = SelectObject(mask_dc, mask_bitmap);
  RECT bounds{0, 0, kIconSize, kIconSize};

  HBRUSH transparent_brush = CreateSolidBrush(RGB(0, 0, 0));
  FillRect(color_dc, &bounds, transparent_brush);
  DeleteObject(transparent_brush);

  HRGN clip_region =
      CreateRoundRectRgn(1, 1, kIconSize - 1, kIconSize - 1, 9, 9);
  SelectClipRgn(color_dc, clip_region);

  RECT claude_bounds{1, 1, kIconSize / 2, kIconSize - 1};
  RECT codex_bounds{kIconSize / 2, 1, kIconSize - 1, kIconSize - 1};
  HBRUSH claude_brush = CreateSolidBrush(kClaudeColor);
  HBRUSH codex_brush = CreateSolidBrush(kCodexColor);
  FillRect(color_dc, &claude_bounds, claude_brush);
  FillRect(color_dc, &codex_bounds, codex_brush);

  HPEN divider_pen = CreatePen(PS_SOLID, 1, RGB(255, 255, 255));
  const HGDIOBJ old_divider_pen = SelectObject(color_dc, divider_pen);
  MoveToEx(color_dc, kIconSize / 2, 3, nullptr);
  LineTo(color_dc, kIconSize / 2, kIconSize - 3);
  SelectObject(color_dc, old_divider_pen);

  RECT claude_text_bounds{0, 0, kIconSize / 2, kIconSize};
  RECT codex_text_bounds{kIconSize / 2, 0, kIconSize, kIconSize};
  DrawStatusText(color_dc, claude_value, claude_text_bounds,
                 claude_value.size() >= 3 ? 10 : 13,
                 claude_value.size() >= 3 ? 4 : 0);
  DrawStatusText(color_dc, codex_value, codex_text_bounds,
                 codex_value.size() >= 3 ? 10 : 13,
                 codex_value.size() >= 3 ? 4 : 0);

  SelectClipRgn(color_dc, nullptr);
  DeleteObject(divider_pen);
  DeleteObject(claude_brush);
  DeleteObject(codex_brush);
  DeleteObject(clip_region);

  PatBlt(mask_dc, 0, 0, kIconSize, kIconSize, WHITENESS);
  HGDIOBJ mask_brush = GetStockObject(BLACK_BRUSH);
  HGDIOBJ mask_pen = GetStockObject(BLACK_PEN);
  const HGDIOBJ old_mask_brush = SelectObject(mask_dc, mask_brush);
  const HGDIOBJ old_mask_pen = SelectObject(mask_dc, mask_pen);
  RoundRect(mask_dc, 1, 1, kIconSize - 1, kIconSize - 1, 9, 9);
  SelectObject(mask_dc, old_mask_pen);
  SelectObject(mask_dc, old_mask_brush);

  SelectObject(color_dc, old_color_bitmap);
  SelectObject(mask_dc, old_mask_bitmap);
  DeleteDC(color_dc);
  DeleteDC(mask_dc);

  ICONINFO icon_info{};
  icon_info.fIcon = TRUE;
  icon_info.hbmColor = color_bitmap;
  icon_info.hbmMask = mask_bitmap;
  HICON icon = CreateIconIndirect(&icon_info);
  DeleteObject(color_bitmap);
  DeleteObject(mask_bitmap);
  return icon;
}

WindowsStatusTray::IconState& WindowsStatusTray::StateFor(UINT id) {
  return icon_states_.at(id - 1);
}

std::optional<std::wstring> WindowsStatusTray::ReadOptionalValue(
    const flutter::EncodableMap& arguments,
    const char* key) const {
  const auto* value = ValueOrNull(arguments, key);
  if (value == nullptr || std::holds_alternative<std::monostate>(*value)) {
    return std::nullopt;
  }
  const auto* text = std::get_if<std::string>(value);
  return text == nullptr ? std::nullopt
                         : std::optional<std::wstring>(Utf8ToWide(*text));
}

void WindowsStatusTray::Destroy() {
  RemoveIcon(kStatusIconId);
  initialized_ = false;
}
