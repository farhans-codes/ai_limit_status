#include "windows_notification_sound.h"

#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <mmsystem.h>

#include <array>
#include <filesystem>
#include <string>

WindowsNotificationSound::WindowsNotificationSound(
    flutter::BinaryMessenger* messenger)
    : channel_(std::make_unique<
               flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "com.ailimitstatus/notification_sound",
          &flutter::StandardMethodCodec::GetInstance())) {
  channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        if (call.method_name() == "play") {
          Play();
          result->Success();
          return;
        }
        result->NotImplemented();
      });
}

WindowsNotificationSound::~WindowsNotificationSound() = default;

bool WindowsNotificationSound::Play() const {
  std::array<wchar_t, 32768> executable_path{};
  const DWORD length = GetModuleFileNameW(
      nullptr, executable_path.data(),
      static_cast<DWORD>(executable_path.size()));
  if (length == 0 || length >= executable_path.size()) {
    MessageBeep(MB_ICONWARNING);
    return false;
  }

  const std::filesystem::path sound_path =
      std::filesystem::path(executable_path.data()).parent_path() /
      L"data" / L"flutter_assets" / L"assets" / L"sounds" /
      L"limit_warning.wav";
  const BOOL played = PlaySoundW(
      sound_path.c_str(), nullptr,
      SND_FILENAME | SND_ASYNC | SND_NODEFAULT);
  if (!played) {
    MessageBeep(MB_ICONWARNING);
  }
  return played == TRUE;
}
