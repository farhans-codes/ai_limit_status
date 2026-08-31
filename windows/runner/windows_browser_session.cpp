#include "windows_browser_session.h"

#include <flutter/standard_method_codec.h>
#include <sddl.h>
#include <windows.h>

#include <algorithm>
#include <array>
#include <atomic>
#include <cstdint>
#include <cstdlib>
#include <functional>
#include <mutex>
#include <optional>
#include <string>
#include <thread>
#include <utility>
#include <vector>

namespace {

constexpr char kChromiumOrigin[] =
    "chrome-extension://hiegdhoebaalcbjijlfbcdkdfokennap/";
constexpr char kFirefoxExtensionId[] = "browser-bridge@ai-limit-status";
constexpr wchar_t kPipeName[] =
    L"\\\\.\\pipe\\AI-Limit-Status-Browser-Session";
constexpr uint32_t kMaximumMessageBytes = 1024 * 1024;

std::mutex snapshot_mutex;
std::string snapshot = "{}";

bool ReadExact(HANDLE input, void* destination, DWORD size) {
  auto* cursor = static_cast<BYTE*>(destination);
  DWORD total = 0;
  while (total < size) {
    DWORD bytes_read = 0;
    if (!ReadFile(input, cursor + total, size - total, &bytes_read, nullptr) ||
        bytes_read == 0) {
      return false;
    }
    total += bytes_read;
  }
  return true;
}

bool CreateCurrentUserSecurityAttributes(
    SECURITY_ATTRIBUTES* attributes,
    PSECURITY_DESCRIPTOR* descriptor) {
  HANDLE token = nullptr;
  if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) {
    return false;
  }

  DWORD size = 0;
  GetTokenInformation(token, TokenUser, nullptr, 0, &size);
  std::vector<BYTE> buffer(size);
  if (size == 0 ||
      !GetTokenInformation(token, TokenUser, buffer.data(), size, &size)) {
    CloseHandle(token);
    return false;
  }
  CloseHandle(token);

  const auto* token_user = reinterpret_cast<const TOKEN_USER*>(buffer.data());
  wchar_t* sid = nullptr;
  if (!ConvertSidToStringSidW(token_user->User.Sid, &sid)) {
    return false;
  }
  const std::wstring sddl =
      L"D:P(A;;GA;;;SY)(A;;GA;;;" + std::wstring(sid) + L")";
  LocalFree(sid);

  if (!ConvertStringSecurityDescriptorToSecurityDescriptorW(
          sddl.c_str(), SDDL_REVISION_1, descriptor, nullptr)) {
    return false;
  }
  attributes->nLength = sizeof(SECURITY_ATTRIBUTES);
  attributes->lpSecurityDescriptor = *descriptor;
  attributes->bInheritHandle = FALSE;
  return true;
}

void ServeSnapshots(const std::atomic<bool>& stopping) {
  SECURITY_ATTRIBUTES attributes{};
  PSECURITY_DESCRIPTOR descriptor = nullptr;
  if (!CreateCurrentUserSecurityAttributes(&attributes, &descriptor)) {
    return;
  }

  while (!stopping.load()) {
    const HANDLE pipe = CreateNamedPipeW(
        kPipeName, PIPE_ACCESS_DUPLEX,
        PIPE_TYPE_MESSAGE | PIPE_READMODE_MESSAGE | PIPE_WAIT |
            PIPE_REJECT_REMOTE_CLIENTS,
        PIPE_UNLIMITED_INSTANCES, kMaximumMessageBytes, 32, 500, &attributes);
    if (pipe == INVALID_HANDLE_VALUE) {
      Sleep(250);
      continue;
    }

    const BOOL connected =
        ConnectNamedPipe(pipe, nullptr) || GetLastError() == ERROR_PIPE_CONNECTED;
    if (connected && !stopping.load()) {
      std::array<char, 32> request{};
      DWORD bytes_read = 0;
      if (ReadFile(pipe, request.data(), static_cast<DWORD>(request.size()),
                   &bytes_read, nullptr) &&
          bytes_read > 0) {
        std::string current_snapshot;
        {
          const std::lock_guard<std::mutex> lock(snapshot_mutex);
          current_snapshot = snapshot;
        }
        DWORD bytes_written = 0;
        WriteFile(pipe, current_snapshot.data(),
                  static_cast<DWORD>(current_snapshot.size()), &bytes_written,
                  nullptr);
      }
    }
    DisconnectNamedPipe(pipe);
    CloseHandle(pipe);
  }
  LocalFree(descriptor);
}

void WakePipeServer() {
  const HANDLE pipe = CreateFileW(kPipeName, GENERIC_READ | GENERIC_WRITE, 0,
                                  nullptr, OPEN_EXISTING, 0, nullptr);
  if (pipe == INVALID_HANDLE_VALUE) {
    return;
  }
  constexpr char request[] = "stop";
  DWORD bytes_written = 0;
  WriteFile(pipe, request, sizeof(request), &bytes_written, nullptr);
  CloseHandle(pipe);
}

std::optional<std::string> ReadSnapshot() {
  char request[] = "read";
  std::vector<char> output(kMaximumMessageBytes);
  DWORD bytes_read = 0;
  if (!CallNamedPipeW(kPipeName, request, sizeof(request),
                      output.data(), static_cast<DWORD>(output.size()),
                      &bytes_read, 500) ||
      bytes_read == 0) {
    return std::nullopt;
  }
  return std::string(output.data(), bytes_read);
}

}  // namespace

bool IsWindowsBrowserSessionHostInvocation(
    const std::vector<std::string>& arguments) {
  return std::find(arguments.begin(), arguments.end(), kChromiumOrigin) !=
             arguments.end() ||
         std::find(arguments.begin(), arguments.end(), kFirefoxExtensionId) !=
             arguments.end();
}

int RunWindowsBrowserSessionHost() {
  const HANDLE input = GetStdHandle(STD_INPUT_HANDLE);
  if (input == nullptr || input == INVALID_HANDLE_VALUE) {
    return EXIT_FAILURE;
  }

  std::atomic<bool> stopping = false;
  std::thread pipe_server(ServeSnapshots, std::cref(stopping));

  while (true) {
    uint32_t message_size = 0;
    if (!ReadExact(input, &message_size,
                   static_cast<DWORD>(sizeof(message_size))) ||
        message_size == 0 ||
        message_size > kMaximumMessageBytes) {
      break;
    }
    std::string message(message_size, '\0');
    if (!ReadExact(input, message.data(), message_size)) {
      break;
    }
    if (message.front() != '{' || message.back() != '}') {
      continue;
    }
    const std::lock_guard<std::mutex> lock(snapshot_mutex);
    snapshot = std::move(message);
  }

  stopping.store(true);
  WakePipeServer();
  pipe_server.join();
  return EXIT_SUCCESS;
}

WindowsBrowserSession::WindowsBrowserSession(
    flutter::BinaryMessenger* messenger)
    : channel_(std::make_unique<
               flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "com.ailimitstatus/keychain",
          &flutter::StandardMethodCodec::GetInstance())) {
  channel_->SetMethodCallHandler([](const auto& call, auto result) {
    if (call.method_name() != "readWindowsBrowserSessions") {
      result->NotImplemented();
      return;
    }
    const auto current_snapshot = ReadSnapshot();
    if (current_snapshot) {
      result->Success(flutter::EncodableValue(*current_snapshot));
    } else {
      result->Success();
    }
  });
}

WindowsBrowserSession::~WindowsBrowserSession() = default;
