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
constexpr int kSegmentWidth = 88;
constexpr int kOverlayHeight = 34;
constexpr int kSegmentGap = 4;
constexpr int kTaskbarPadding = 8;
constexpr int kProviderIconSize = 20;
constexpr int kProviderFontSize = 16;
constexpr int kProviderContentPadding = 6;
constexpr int kProviderIconGap = 6;
constexpr COLORREF kProviderForeground = RGB(255, 255, 255);
constexpr UINT kRefreshOverlayOrder = WM_APP + 42;
constexpr DWORD kTransparentSentinelRgb = 0x00010203;
constexpr BYTE kHitSurfaceAlpha = 1;

bool IsWindowAbove(HWND window, HWND other) {
  if (window == nullptr || other == nullptr || window == other) {
    return false;
  }
  struct WindowOrder {
    HWND window;
    HWND other;
    bool above = false;
  } order{window, other};
  EnumWindows(
      [](HWND current, LPARAM data) -> BOOL {
        auto& order = *reinterpret_cast<WindowOrder*>(data);
        if (current == order.window) {
          order.above = true;
          return FALSE;
        }
        return current != order.other;
      },
      reinterpret_cast<LPARAM>(&order));
  return order.above;
}

bool PointIsInsideWindow(HWND window, const POINT& point) {
  if (window == nullptr || !IsWindowVisible(window)) {
    return false;
  }
  RECT bounds{};
  return GetWindowRect(window, &bounds) && PtInRect(&bounds, point);
}

bool PointIsInsideWindowClass(const wchar_t* class_name, const POINT& point) {
  HWND window = nullptr;
  while ((window = FindWindowExW(nullptr, window, class_name, nullptr)) !=
         nullptr) {
    if (PointIsInsideWindow(window, point)) {
      return true;
    }
  }
  return false;
}

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
  if (value.empty()) {
    return L"--";
  }
  if (std::all_of(value.begin(), value.end(),
                  [](wchar_t ch) { return ch >= L'0' && ch <= L'9'; })) {
    return value + L'%';
  }
  return value;
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
  if (method_call.method_name() == "isPointerOverTaskbarUi") {
    result->Success(flutter::EncodableValue(IsPointerOverTaskbarUi()));
    return;
  }
  if (method_call.method_name() == "showPopover") {
    ShowPopover();
    result->Success(flutter::EncodableValue(IsPopoverVisible()));
    return;
  }
  if (method_call.method_name() == "hidePopover") {
    HidePopover();
    result->Success();
    return;
  }
  if (method_call.method_name() == "togglePopover") {
    TogglePopover();
    result->Success(flutter::EncodableValue(IsPopoverVisible()));
    return;
  }
  if (method_call.method_name() == "isPopoverVisible") {
    result->Success(flutter::EncodableValue(IsPopoverVisible()));
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
    SetTimer(overlay_window_, 1, 1000, nullptr);
    // These callbacks only schedule a check on our own message loop. No
    // injection, mouse hook, or repeated foreground activation is needed.
    if (foreground_hook_ == nullptr) {
      foreground_hook_ = SetWinEventHook(
          EVENT_SYSTEM_FOREGROUND, EVENT_SYSTEM_FOREGROUND, nullptr,
          OnShellWindowEvent, 0, 0,
          WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS);
    }
    if (reorder_hook_ == nullptr) {
      reorder_hook_ = SetWinEventHook(
          EVENT_OBJECT_REORDER, EVENT_OBJECT_REORDER, nullptr,
          OnShellWindowEvent, 0, 0,
          WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS);
    }
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
  // Content changed: force the next PositionOverlay to repaint.
  last_rendered_signature_.clear();
  PositionOverlay();
}

void WindowsTaskbarStatus::PositionOverlay() {
  if (!initialized_ || overlay_window_ == nullptr) {
    return;
  }
  const HWND taskbar = FindWindowW(L"Shell_TrayWnd", nullptr);
  if (taskbar == nullptr || !IsWindowVisible(taskbar)) {
    ShowWindow(overlay_window_, SW_HIDE);
    overlay_rendered_ = false;
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
    overlay_rendered_ = false;
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

  // Drawing and window order are independent: an unchanged bitmap can still
  // be behind Explorer after a taskbar click.
  const RECT bounds{x, y, x + width, y + height};
  std::wstring signature = tooltip_;
  signature += L'|';
  signature += codex_value_.value_or(L"<none>");
  signature += L'|';
  signature += claude_value_.value_or(L"<none>");
  signature += L'|';
  signature += std::to_wstring(dpi);
  if (overlay_rendered_ && IsWindowVisible(overlay_window_) &&
      EqualRect(&bounds, &last_overlay_bounds_) &&
      signature == last_rendered_signature_) {
    EnsureOverlayAboveTaskbar(taskbar);
    return;
  }

  if (RenderLayeredOverlay(x, y, width, height, dpi)) {
    ShowWindow(overlay_window_, SW_SHOWNOACTIVATE);
    last_overlay_bounds_ = bounds;
    last_rendered_signature_ = std::move(signature);
    overlay_rendered_ = true;
    EnsureOverlayAboveTaskbar(taskbar);
  } else {
    overlay_rendered_ = false;
  }
}

void WindowsTaskbarStatus::EnsureOverlayAboveTaskbar(HWND taskbar) {
  if (!IsWindowAbove(taskbar, overlay_window_)) {
    return;
  }
  // Keep our details window above the indicator when it is already above
  // Explorer. Restore only lost order, without redrawing or stealing focus.
  const HWND insert_after =
      IsPopoverVisible() && IsWindowAbove(host_window_, taskbar)
          ? host_window_
          : HWND_TOPMOST;
  SetWindowPos(overlay_window_, insert_after, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_NOOWNERZORDER);
}

bool WindowsTaskbarStatus::IsPopoverVisible() const {
  return host_window_ != nullptr && IsWindowVisible(host_window_) != FALSE;
}

RECT WindowsTaskbarStatus::PopoverBoundsAnchoredToTaskbar(int width,
                                                          int height) const {
  // Anchor to the overlay when it is on screen, otherwise to the cursor
  // (for example when the taskbar could not be found).
  RECT anchor{};
  const bool has_overlay =
      overlay_window_ != nullptr && IsWindowVisible(overlay_window_) &&
      GetWindowRect(overlay_window_, &anchor);
  if (!has_overlay) {
    POINT cursor{};
    GetCursorPos(&cursor);
    anchor = RECT{cursor.x, cursor.y, cursor.x, cursor.y};
  }

  HMONITOR monitor = MonitorFromRect(&anchor, MONITOR_DEFAULTTONEAREST);
  MONITORINFO monitor_info{};
  monitor_info.cbSize = sizeof(monitor_info);
  RECT work{};
  if (GetMonitorInfoW(monitor, &monitor_info)) {
    // rcWork excludes the taskbar, so the window never opens underneath it.
    work = monitor_info.rcWork;
  } else {
    work = RECT{0, 0, GetSystemMetrics(SM_CXSCREEN),
                GetSystemMetrics(SM_CYSCREEN)};
  }
  const UINT dpi = DpiForWindowOrDefault(
      has_overlay ? overlay_window_ : host_window_);
  const int gap = ScaleForDpi(10, dpi);

  const int anchor_center_x = (anchor.left + anchor.right) / 2;
  const int anchor_center_y = (anchor.top + anchor.bottom) / 2;
  int x = anchor_center_x - width / 2;
  int y = 0;
  if (anchor.top >= work.bottom) {
    // Taskbar at the bottom: open upward.
    y = anchor.top - height - gap;
  } else if (anchor.bottom <= work.top) {
    // Taskbar at the top: open downward.
    y = anchor.bottom + gap;
  } else if (anchor.right <= work.left) {
    // Taskbar on the left: open to the right.
    x = anchor.right + gap;
    y = anchor_center_y - height / 2;
  } else if (anchor.left >= work.right) {
    // Taskbar on the right: open to the left.
    x = anchor.left - width - gap;
    y = anchor_center_y - height / 2;
  } else {
    // Anchor inside the work area (cursor fallback): prefer above.
    y = anchor.top - height - gap;
    if (y < work.top) {
      y = anchor.bottom + gap;
    }
  }

  const int max_x = std::max(static_cast<int>(work.left),
                             static_cast<int>(work.right) - width);
  const int max_y = std::max(static_cast<int>(work.top),
                             static_cast<int>(work.bottom) - height);
  x = std::min(std::max(x, static_cast<int>(work.left)), max_x);
  y = std::min(std::max(y, static_cast<int>(work.top)), max_y);
  return RECT{x, y, x + width, y + height};
}

void WindowsTaskbarStatus::ShowPopover() {
  if (host_window_ == nullptr) {
    return;
  }
  RECT host{};
  if (!GetWindowRect(host_window_, &host)) {
    return;
  }
  const int width = host.right - host.left;
  const int height = host.bottom - host.top;
  const RECT bounds = PopoverBoundsAnchoredToTaskbar(width, height);

  // Dart is told first so its blur handling can ignore the activation churn
  // that showing and focusing the window produces.
  InvokeDart("popoverWillShow");
  SetWindowPos(host_window_, HWND_TOPMOST, bounds.left, bounds.top, 0, 0,
               SWP_NOSIZE | SWP_NOOWNERZORDER | SWP_SHOWWINDOW);
  // Called on the thread that received the click, so the foreground lock
  // allows it even though the overlay itself never activates.
  if (!SetForegroundWindow(host_window_)) {
    // Fall back to the async request when another process holds the lock;
    // the window is still visible and topmost either way.
    SetActiveWindow(host_window_);
  }
  OutputDebugStringW(L"[AI Limit Status] popover shown\n");
  InvokeDart("popoverShown");
}

void WindowsTaskbarStatus::HidePopover() {
  if (host_window_ == nullptr) {
    return;
  }
  ShowWindow(host_window_, SW_HIDE);
  OutputDebugStringW(L"[AI Limit Status] popover hidden\n");
  InvokeDart("popoverHidden");
}

void WindowsTaskbarStatus::TogglePopover() {
  if (IsPopoverVisible()) {
    HidePopover();
  } else {
    ShowPopover();
  }
}

bool WindowsTaskbarStatus::RenderLayeredOverlay(int x,
                                                int y,
                                                int width,
                                                int height,
                                                UINT dpi) {
  if (overlay_window_ == nullptr || width <= 0 || height <= 0) {
    return false;
  }

  HDC screen_dc = GetDC(nullptr);
  HDC buffer_dc = CreateCompatibleDC(screen_dc);
  BITMAPINFO bitmap_info{};
  bitmap_info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  bitmap_info.bmiHeader.biWidth = width;
  bitmap_info.bmiHeader.biHeight = -height;
  bitmap_info.bmiHeader.biPlanes = 1;
  bitmap_info.bmiHeader.biBitCount = 32;
  bitmap_info.bmiHeader.biCompression = BI_RGB;

  void* bitmap_bits = nullptr;
  HBITMAP buffer_bitmap = CreateDIBSection(
      screen_dc, &bitmap_info, DIB_RGB_COLORS, &bitmap_bits, nullptr, 0);
  if (screen_dc == nullptr || buffer_dc == nullptr ||
      buffer_bitmap == nullptr || bitmap_bits == nullptr) {
    if (buffer_dc != nullptr) DeleteDC(buffer_dc);
    if (buffer_bitmap != nullptr) DeleteObject(buffer_bitmap);
    if (screen_dc != nullptr) ReleaseDC(nullptr, screen_dc);
    return false;
  }

  const HGDIOBJ old_bitmap = SelectObject(buffer_dc, buffer_bitmap);
  auto* pixels = static_cast<DWORD*>(bitmap_bits);
  const size_t pixel_count =
      static_cast<size_t>(width) * static_cast<size_t>(height);
  std::fill_n(pixels, pixel_count, kTransparentSentinelRgb);

  const RECT client{0, 0, width, height};
  PaintOverlay(buffer_dc, client, dpi);

  // GDI batches writes to the DIB. Flush before reading or changing its
  // pixels, otherwise a late draw can erase alpha and make visible glyphs
  // pass mouse clicks through to the taskbar below.
  GdiFlush();

  for (size_t index = 0; index < pixel_count; ++index) {
    const DWORD rgb = pixels[index] & 0x00FFFFFF;
    pixels[index] = rgb == kTransparentSentinelRgb
                        ? static_cast<DWORD>(kHitSurfaceAlpha) << 24
                        : 0xFF000000 | rgb;
  }

  POINT destination{x, y};
  POINT source{0, 0};
  SIZE size{width, height};
  BLENDFUNCTION blend{};
  blend.BlendOp = AC_SRC_OVER;
  blend.SourceConstantAlpha = 255;
  blend.AlphaFormat = AC_SRC_ALPHA;
  const BOOL updated = UpdateLayeredWindow(
      overlay_window_, screen_dc, &destination, &size, buffer_dc, &source, 0,
      &blend, ULW_ALPHA);

  SelectObject(buffer_dc, old_bitmap);
  DeleteObject(buffer_bitmap);
  DeleteDC(buffer_dc);
  ReleaseDC(nullptr, screen_dc);
  return updated != FALSE;
}

void WindowsTaskbarStatus::PaintOverlay(HDC dc, const RECT& client, UINT dpi) {
  std::array<std::pair<std::wstring, bool>, 2> providers{};
  int provider_count = 0;
  if (codex_value_.has_value()) {
    providers[provider_count++] = {DisplayValue(*codex_value_), false};
  }
  if (claude_value_.has_value()) {
    providers[provider_count++] = {DisplayValue(*claude_value_), true};
  }

  if (provider_count == 0) {
    PaintProvider(dc, client, L"AI", false, dpi);
  } else {
    const int gap = provider_count == 2
                        ? ScaleForDpi(kSegmentGap, dpi)
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
      PaintProvider(dc, segment, providers[index].first,
                    providers[index].second, dpi);
    }
  }
}

void WindowsTaskbarStatus::PaintProvider(HDC dc,
                                         const RECT& bounds,
                                         const std::wstring& value,
                                         bool is_claude,
                                         UINT dpi) const {
  const int icon_size = ScaleForDpi(kProviderIconSize, dpi);
  const int padding = ScaleForDpi(kProviderContentPadding, dpi);
  const int center_y = (bounds.top + bounds.bottom) / 2;
  RECT mark_bounds{bounds.left + padding, center_y - icon_size / 2,
                   bounds.left + padding + icon_size,
                   center_y - icon_size / 2 + icon_size};
  PaintProviderMark(dc, mark_bounds, is_claude);

  RECT text_bounds = bounds;
  text_bounds.left = mark_bounds.right + ScaleForDpi(kProviderIconGap, dpi);
  text_bounds.right -= padding;
  const int font_height = ScaleForDpi(kProviderFontSize, dpi);
  HFONT font = CreateFontW(-font_height, 0, 0, 0, FW_BOLD, FALSE, FALSE,
                           FALSE, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS,
                           CLIP_DEFAULT_PRECIS, ANTIALIASED_QUALITY,
                           DEFAULT_PITCH, L"Segoe UI");
  const HGDIOBJ old_font = SelectObject(dc, font);
  SetBkMode(dc, TRANSPARENT);
  SetTextColor(dc, kProviderForeground);
  DrawTextW(dc, value.c_str(), -1, &text_bounds,
            DT_LEFT | DT_VCENTER | DT_SINGLELINE | DT_NOPREFIX);
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
      4, static_cast<int>(bounds.bottom - bounds.top) / 2 - 1);
  HPEN pen = CreatePen(PS_SOLID, std::max(1, radius / 3),
                       kProviderForeground);
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
      ShowPopover();
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

bool WindowsTaskbarStatus::IsPointerOverTaskbarUi() const {
  POINT pointer{};
  if (!GetCursorPos(&pointer)) {
    return false;
  }
  if (PointIsInsideWindow(overlay_window_, pointer)) {
    return true;
  }
  return PointIsInsideWindowClass(L"Shell_TrayWnd", pointer) ||
         PointIsInsideWindowClass(L"Shell_SecondaryTrayWnd", pointer) ||
         PointIsInsideWindowClass(L"NotifyIconOverflowWindow", pointer) ||
         PointIsInsideWindowClass(L"TopLevelWindowForOverflowXamlIsland",
                                  pointer);
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
  if (foreground_hook_ != nullptr) {
    UnhookWinEvent(foreground_hook_);
    foreground_hook_ = nullptr;
  }
  if (reorder_hook_ != nullptr) {
    UnhookWinEvent(reorder_hook_);
    reorder_hook_ = nullptr;
  }
  if (overlay_window_ != nullptr) {
    KillTimer(overlay_window_, 1);
    DestroyWindow(overlay_window_);
    overlay_window_ = nullptr;
  }
  initialized_ = false;
}

void CALLBACK WindowsTaskbarStatus::OnShellWindowEvent(
    HWINEVENTHOOK, DWORD event, HWND window, LONG object_id, LONG,
    DWORD, DWORD) {
  // Ignore list/tree reorders inside other applications. Foreground changes
  // and top-level window reorders can change Explorer's stacking order.
  if (event == EVENT_OBJECT_REORDER && object_id != OBJID_WINDOW &&
      window != GetDesktopWindow()) {
    return;
  }
  const HWND overlay = FindWindowW(kOverlayClassName, nullptr);
  if (overlay != nullptr) {
    PostMessageW(overlay, kRefreshOverlayOrder, 0, 0);
  }
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
        ValidateRect(window, nullptr);
        return 0;
      case WM_ERASEBKGND:
        return 1;
      case WM_LBUTTONUP:
        OutputDebugStringW(L"[AI Limit Status] overlay clicked\n");
        status->TogglePopover();
        return 0;
      case WM_RBUTTONUP:
        status->ShowContextMenu();
        return 0;
      case WM_TIMER:
      case kRefreshOverlayOrder:
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
