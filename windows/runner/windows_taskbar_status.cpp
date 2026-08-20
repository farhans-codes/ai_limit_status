#include "windows_taskbar_status.h"

#include "resource.h"

#include <flutter/standard_method_codec.h>
#include <strsafe.h>

#include <algorithm>
#include <array>
#include <utility>

namespace {

constexpr UINT kOpenCommand = 1001;
constexpr UINT kRefreshCommand = 1002;
constexpr UINT kQuitCommand = 1003;
constexpr int kSegmentWidth = 68;
constexpr int kOverlayHeight = 34;
constexpr int kSegmentGap = 4;
constexpr int kTaskbarPadding = 8;
constexpr COLORREF kTransparentColor = RGB(1, 2, 3);

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

int ScaleForDpi(int value, UINT dpi) {
  return MulDiv(value, static_cast<int>(dpi), 96);
}

UINT DpiForWindowOrDefault(HWND window) {
  if (window == nullptr) {
    return 96;
  }
  using GetDpiForWindowFunction = UINT(WINAPI*)(HWND);
  const HMODULE user32 = GetModuleHandleW(L"user32.dll");
  const auto get_dpi_for_window =
      user32 == nullptr
          ? nullptr
          : reinterpret_cast<GetDpiForWindowFunction>(
                GetProcAddress(user32, "GetDpiForWindow"));
  return get_dpi_for_window == nullptr ? 96 : get_dpi_for_window(window);
}

}  // namespace

WindowsTaskbarStatus::WindowsTaskbarStatus(flutter::BinaryMessenger* messenger,
                                           HWND host_window)
    : host_window_(host_window),
      taskbar_created_message_(RegisterWindowMessageW(L"TaskbarCreated")),
      channel_(std::make_unique<
               flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "com.ailimitstatus/windows_taskbar_status",
          &flutter::StandardMethodCodec::GetInstance())) {
  channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleMethodCall(call, std::move(result));
      });
}

WindowsTaskbarStatus::~WindowsTaskbarStatus() {
  Destroy();
}

void WindowsTaskbarStatus::HandleMethodCall(
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
    UpdateOverlay();
    result->Success();
    return;
  }
  if (method_call.method_name() == "update" && arguments != nullptr) {
    codex_value_ = ReadOptionalValue(*arguments, "codexValue");
    claude_value_ = ReadOptionalValue(*arguments, "claudeValue");
    tooltip_ = RequiredString(*arguments, "tooltip");
    UpdateOverlay();
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

std::optional<LRESULT> WindowsTaskbarStatus::HandleMessage(UINT message,
                                                            WPARAM wparam,
                                                            LPARAM lparam) {
  if (message == taskbar_created_message_ && initialized_) {
    if (overlay_window_ != nullptr) {
      DestroyWindow(overlay_window_);
      overlay_window_ = nullptr;
    }
    UpdateOverlay();
    return 0;
  }
  if (message == WM_DISPLAYCHANGE || message == WM_SETTINGCHANGE ||
      message == WM_DPICHANGED) {
    PositionOverlay();
  }
  return std::nullopt;
}

void WindowsTaskbarStatus::CreateOverlayIfNeeded() {
  if (overlay_window_ != nullptr) {
    return;
  }

  WNDCLASSW window_class{};
  window_class.hCursor = LoadCursor(nullptr, IDC_HAND);
  window_class.hInstance = GetModuleHandleW(nullptr);
  window_class.lpszClassName = kOverlayClassName;
  window_class.lpfnWndProc = OverlayWindowProc;
  RegisterClassW(&window_class);

  overlay_window_ = CreateWindowExW(
      WS_EX_LAYERED | WS_EX_TOOLWINDOW | WS_EX_TOPMOST | WS_EX_NOACTIVATE,
      kOverlayClassName, tooltip_.c_str(), WS_POPUP, 0, 0, 1, 1, nullptr,
      nullptr, GetModuleHandleW(nullptr), this);
  if (overlay_window_ != nullptr) {
    SetLayeredWindowAttributes(overlay_window_, kTransparentColor, 0,
                               LWA_COLORKEY);
    SetTimer(overlay_window_, 1, 1000, nullptr);
  }
}

void WindowsTaskbarStatus::UpdateOverlay() {
  if (!initialized_) {
    return;
  }
  CreateOverlayIfNeeded();
  if (overlay_window_ == nullptr) {
    return;
  }
  SetWindowTextW(overlay_window_, tooltip_.c_str());
  PositionOverlay();
  InvalidateRect(overlay_window_, nullptr, TRUE);
  ShowWindow(overlay_window_, SW_SHOWNOACTIVATE);
  UpdateWindow(overlay_window_);
}

void WindowsTaskbarStatus::PositionOverlay() {
  if (!initialized_ || overlay_window_ == nullptr) {
    return;
  }
  const HWND taskbar = FindWindowW(L"Shell_TrayWnd", nullptr);
  if (taskbar == nullptr) {
    ShowWindow(overlay_window_, SW_HIDE);
    return;
  }

  RECT taskbar_bounds{};
  if (!GetWindowRect(taskbar, &taskbar_bounds)) {
    return;
  }
  const UINT dpi = DpiForWindowOrDefault(taskbar);
  const int provider_count =
      std::max(1, static_cast<int>(codex_value_.has_value()) +
                      static_cast<int>(claude_value_.has_value()));
  const int width = ScaleForDpi(
      provider_count * kSegmentWidth + (provider_count - 1) * kSegmentGap,
      dpi);
  const int height = ScaleForDpi(kOverlayHeight, dpi);
  const int padding = ScaleForDpi(kTaskbarPadding, dpi);

  int x = taskbar_bounds.left + padding;
  int y = taskbar_bounds.top + padding;
  const bool horizontal =
      (taskbar_bounds.right - taskbar_bounds.left) >=
      (taskbar_bounds.bottom - taskbar_bounds.top);
  const int taskbar_thickness = horizontal
                                    ? taskbar_bounds.bottom - taskbar_bounds.top
                                    : taskbar_bounds.right - taskbar_bounds.left;
  if (taskbar_thickness < ScaleForDpi(24, dpi)) {
    ShowWindow(overlay_window_, SW_HIDE);
    return;
  }
  const HWND notification_area =
      FindWindowExW(taskbar, nullptr, L"TrayNotifyWnd", nullptr);
  RECT notification_bounds{};
  const bool has_notification_bounds =
      notification_area != nullptr &&
      GetWindowRect(notification_area, &notification_bounds);

  if (horizontal) {
    const int right_anchor = has_notification_bounds
                                 ? notification_bounds.left
                                 : taskbar_bounds.right -
                                       ScaleForDpi(210, dpi);
    x = std::max(static_cast<int>(taskbar_bounds.left) + padding,
                 right_anchor - width - padding);
    y = taskbar_bounds.top +
        ((taskbar_bounds.bottom - taskbar_bounds.top) - height) / 2;
  } else {
    const int bottom_anchor = has_notification_bounds
                                  ? notification_bounds.top
                                  : taskbar_bounds.bottom -
                                        ScaleForDpi(210, dpi);
    x = taskbar_bounds.left +
        ((taskbar_bounds.right - taskbar_bounds.left) - width) / 2;
    y = std::max(static_cast<int>(taskbar_bounds.top) + padding,
                 bottom_anchor - height - padding);
  }

  SetWindowPos(overlay_window_, HWND_TOPMOST, x, y, width, height,
               SWP_NOACTIVATE | SWP_SHOWWINDOW);
}

void WindowsTaskbarStatus::PaintOverlay() {
  if (overlay_window_ == nullptr) {
    return;
  }
  PAINTSTRUCT paint{};
  HDC window_dc = BeginPaint(overlay_window_, &paint);
  if (window_dc == nullptr) {
    return;
  }

  RECT client{};
  GetClientRect(overlay_window_, &client);
  HDC buffer_dc = CreateCompatibleDC(window_dc);
  HBITMAP buffer_bitmap = CreateCompatibleBitmap(
      window_dc, client.right - client.left, client.bottom - client.top);
  if (buffer_dc == nullptr || buffer_bitmap == nullptr) {
    if (buffer_dc != nullptr) DeleteDC(buffer_dc);
    if (buffer_bitmap != nullptr) DeleteObject(buffer_bitmap);
    EndPaint(overlay_window_, &paint);
    return;
  }

  const HGDIOBJ old_bitmap = SelectObject(buffer_dc, buffer_bitmap);
  HBRUSH transparent = CreateSolidBrush(kTransparentColor);
  FillRect(buffer_dc, &client, transparent);
  DeleteObject(transparent);

  std::array<std::pair<std::wstring, bool>, 2> providers{};
  int provider_count = 0;
  if (codex_value_.has_value()) {
    providers[provider_count++] = {DisplayValue(*codex_value_), false};
  }
  if (claude_value_.has_value()) {
    providers[provider_count++] = {DisplayValue(*claude_value_), true};
  }

  if (provider_count == 0) {
    PaintProvider(buffer_dc, client, L"AI", false);
  } else {
    const int gap = provider_count == 2
                        ? ScaleForDpi(kSegmentGap,
                                      DpiForWindowOrDefault(overlay_window_))
                        : 0;
    const int segment_width =
        ((client.right - client.left) - gap) / provider_count;
    for (int index = 0; index < provider_count; ++index) {
      RECT segment{
          index * (segment_width + gap),
          client.top,
          index * (segment_width + gap) + segment_width,
          client.bottom,
      };
      PaintProvider(buffer_dc, segment, providers[index].first,
                    providers[index].second);
    }
  }

  BitBlt(window_dc, 0, 0, client.right, client.bottom, buffer_dc, 0, 0,
         SRCCOPY);
  SelectObject(buffer_dc, old_bitmap);
  DeleteObject(buffer_bitmap);
  DeleteDC(buffer_dc);
  EndPaint(overlay_window_, &paint);
}

void WindowsTaskbarStatus::PaintProvider(HDC dc,
                                         const RECT& bounds,
                                         const std::wstring& value,
                                         bool is_claude) const {
  const int height = bounds.bottom - bounds.top;
  RECT content_bounds = bounds;
  content_bounds.top += std::max(1, height / 12);
  content_bounds.bottom -= std::max(1, height / 12);

  RECT mark_bounds = content_bounds;
  mark_bounds.left += std::max(5, height / 7);
  mark_bounds.right = mark_bounds.left + std::max(14, height / 2);
  PaintProviderMark(dc, mark_bounds, is_claude);

  RECT text_bounds = content_bounds;
  text_bounds.left = mark_bounds.right + std::max(2, height / 16);
  text_bounds.right -= std::max(4, height / 8);
  const int font_height = value.size() >= 3 ? height * 38 / 100
                                            : height * 44 / 100;
  HFONT font = CreateFontW(-font_height, 0, 0, 0, FW_BOLD, FALSE, FALSE,
                           FALSE, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS,
                           CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                           DEFAULT_PITCH, L"Segoe UI");
  const HGDIOBJ old_font = SelectObject(dc, font);
  SetBkMode(dc, TRANSPARENT);
  SetTextColor(dc, RGB(255, 255, 255));
  DrawTextW(dc, value.c_str(), -1, &text_bounds,
            DT_CENTER | DT_VCENTER | DT_SINGLELINE | DT_NOPREFIX);
  SelectObject(dc, old_font);
  DeleteObject(font);
}

void WindowsTaskbarStatus::PaintProviderMark(HDC dc,
                                             const RECT& bounds,
                                             bool is_claude) const {
  const int center_x = (bounds.left + bounds.right) / 2;
  const int center_y = (bounds.top + bounds.bottom) / 2;
  if (!is_claude) {
    const int icon_width = static_cast<int>(bounds.right - bounds.left);
    const int icon_height = static_cast<int>(bounds.bottom - bounds.top);
    const int icon_size = std::max(12, std::min(icon_width, icon_height));
    HICON icon = static_cast<HICON>(LoadImageW(
        GetModuleHandleW(nullptr), MAKEINTRESOURCEW(IDI_CODEX_STATUS_ICON),
        IMAGE_ICON, icon_size, icon_size, LR_DEFAULTCOLOR));
    if (icon != nullptr) {
      DrawIconEx(dc, center_x - icon_size / 2, center_y - icon_size / 2, icon,
                 icon_size, icon_size, 0, nullptr, DI_NORMAL);
      DestroyIcon(icon);
      return;
    }
  }

  const int radius = std::max(
      4, static_cast<int>(bounds.bottom - bounds.top) / 4);
  HPEN pen = CreatePen(PS_SOLID, std::max(1, radius / 3),
                       RGB(255, 255, 255));
  const HGDIOBJ old_pen = SelectObject(dc, pen);
  const HGDIOBJ old_brush = SelectObject(dc, GetStockObject(NULL_BRUSH));

  if (is_claude) {
    MoveToEx(dc, center_x - radius, center_y, nullptr);
    LineTo(dc, center_x + radius, center_y);
    MoveToEx(dc, center_x, center_y - radius, nullptr);
    LineTo(dc, center_x, center_y + radius);
    MoveToEx(dc, center_x - radius * 3 / 4,
             center_y - radius * 3 / 4, nullptr);
    LineTo(dc, center_x + radius * 3 / 4,
           center_y + radius * 3 / 4);
    MoveToEx(dc, center_x + radius * 3 / 4,
             center_y - radius * 3 / 4, nullptr);
    LineTo(dc, center_x - radius * 3 / 4,
           center_y + radius * 3 / 4);
  } else {
    Ellipse(dc, center_x - radius, center_y - radius,
            center_x + radius, center_y + radius);
    Ellipse(dc, center_x - radius / 2, center_y - radius / 2,
            center_x + radius / 2, center_y + radius / 2);
  }

  SelectObject(dc, old_brush);
  SelectObject(dc, old_pen);
  DeleteObject(pen);
}

void WindowsTaskbarStatus::ShowContextMenu() {
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
  SetForegroundWindow(host_window_);
  const UINT command = TrackPopupMenu(
      menu, TPM_RETURNCMD | TPM_NONOTIFY | TPM_RIGHTBUTTON, cursor.x, cursor.y,
      0, host_window_, nullptr);
  DestroyMenu(menu);
  PostMessageW(host_window_, WM_NULL, 0, 0);

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

void WindowsTaskbarStatus::InvokeDart(const std::string& method) {
  channel_->InvokeMethod(method,
                         std::make_unique<flutter::EncodableValue>());
}

std::optional<std::wstring> WindowsTaskbarStatus::ReadOptionalValue(
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

void WindowsTaskbarStatus::Destroy() {
  if (overlay_window_ != nullptr) {
    KillTimer(overlay_window_, 1);
    DestroyWindow(overlay_window_);
    overlay_window_ = nullptr;
  }
  initialized_ = false;
}

LRESULT CALLBACK WindowsTaskbarStatus::OverlayWindowProc(HWND window,
                                                          UINT message,
                                                          WPARAM wparam,
                                                          LPARAM lparam) {
  WindowsTaskbarStatus* status = reinterpret_cast<WindowsTaskbarStatus*>(
      GetWindowLongPtrW(window, GWLP_USERDATA));
  if (message == WM_NCCREATE) {
    const auto* create = reinterpret_cast<CREATESTRUCTW*>(lparam);
    status = static_cast<WindowsTaskbarStatus*>(create->lpCreateParams);
    SetWindowLongPtrW(window, GWLP_USERDATA,
                      reinterpret_cast<LONG_PTR>(status));
  }

  if (status != nullptr) {
    switch (message) {
      case WM_PAINT:
        status->PaintOverlay();
        return 0;
      case WM_ERASEBKGND:
        return 1;
      case WM_LBUTTONUP:
        status->InvokeDart("toggle");
        return 0;
      case WM_RBUTTONUP:
        status->ShowContextMenu();
        return 0;
      case WM_TIMER:
        status->PositionOverlay();
        return 0;
      case WM_MOUSEACTIVATE:
        return MA_NOACTIVATE;
      case WM_NCHITTEST:
        return HTCLIENT;
      default:
        break;
    }
  }
  return DefWindowProcW(window, message, wparam, lparam);
}
