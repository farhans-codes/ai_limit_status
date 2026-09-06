#include "windows_browser_session.h"

#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <bcrypt.h>
#include <wincred.h>

#include "utils.h"

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

std::optional<std::wstring> ClaudeCredentialTarget(
    const std::string& config_directory, int64_t part) {
  std::wstring service = L"Claude Code-credentials";
  if (!config_directory.empty()) {
    const int wide_size = MultiByteToWideChar(
        CP_UTF8, MB_ERR_INVALID_CHARS, config_directory.data(),
        static_cast<int>(config_directory.size()), nullptr, 0);
    if (wide_size <= 0 || wide_size >= UNICODE_STRING_MAX_CHARS) {
      return std::nullopt;
    }
    std::wstring wide(wide_size, L'\0');
    if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                            config_directory.data(),
                            static_cast<int>(config_directory.size()),
                            wide.data(), wide_size) != wide_size) {
      return std::nullopt;
    }
    int normalized_size =
        NormalizeString(NormalizationC, wide.c_str(), -1, nullptr, 0);
    if (normalized_size <= 0 || normalized_size > UNICODE_STRING_MAX_CHARS) {
      return std::nullopt;
    }
    std::vector<wchar_t> normalized(normalized_size);
    normalized_size = NormalizeString(NormalizationC, wide.c_str(), -1,
                                      normalized.data(), normalized_size);
    if (normalized_size < 0 && GetLastError() == ERROR_INSUFFICIENT_BUFFER &&
        normalized_size >= -UNICODE_STRING_MAX_CHARS) {
      normalized.resize(-normalized_size);
      normalized_size = NormalizeString(
          NormalizationC, wide.c_str(), -1, normalized.data(),
          static_cast<int>(normalized.size()));
    }
    if (normalized_size <= 0) {
      return std::nullopt;
    }
    auto utf8 = Utf8FromUtf16(normalized.data());
    if (utf8.empty()) {
      return std::nullopt;
    }
    std::array<UCHAR, 32> digest{};
    BCRYPT_ALG_HANDLE algorithm = nullptr;
    if (BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_SHA256_ALGORITHM,
                                    nullptr, 0) < 0) {
      return std::nullopt;
    }
    BCRYPT_HASH_HANDLE hash = nullptr;
    const bool hashed =
        BCryptCreateHash(algorithm, &hash, nullptr, 0, nullptr, 0, 0) >= 0 &&
        BCryptHashData(hash, reinterpret_cast<PUCHAR>(utf8.data()),
                       static_cast<ULONG>(utf8.size()), 0) >= 0 &&
        BCryptFinishHash(hash, digest.data(),
                         static_cast<ULONG>(digest.size()), 0) >= 0;
    if (hash != nullptr) {
      BCryptDestroyHash(hash);
    }
    BCryptCloseAlgorithmProvider(algorithm, 0);
    if (!hashed) {
      return std::nullopt;
    }
    // Claude Code hashes the NFC config literal, not a canonicalized path.
    constexpr wchar_t hex[] = L"0123456789abcdef";
    service += L'-';
    for (size_t index = 0; index < 4; ++index) {
      service += hex[digest[index] >> 4];
      service += hex[digest[index] & 15];
    }
  }
  // Bun.secrets uses service/name; Claude's large JSON uses #m and #0..#255.
  auto target = service + L"/claude-code-user";
  if (part == -2) {
    target += L"#m";
  } else if (part >= 0) {
    target += L"#" + std::to_wstring(part);
  }
  return target;
}

std::optional<std::vector<uint8_t>> ReadClaudeWindowsCredential(
    const std::wstring& target) {
  PCREDENTIALW credential = nullptr;
  if (!CredReadW(target.c_str(), CRED_TYPE_GENERIC, 0, &credential)) {
    return std::nullopt;
  }
  std::optional<std::vector<uint8_t>> bytes;
  if (credential->CredentialBlobSize <= CRED_MAX_CREDENTIAL_BLOB_SIZE) {
    if (credential->CredentialBlobSize == 0) {
      bytes.emplace();
    } else if (credential->CredentialBlob != nullptr) {
      bytes.emplace(credential->CredentialBlob,
                    credential->CredentialBlob + credential->CredentialBlobSize);
    }
  }
  if (credential->CredentialBlob != nullptr) {
    SecureZeroMemory(credential->CredentialBlob, credential->CredentialBlobSize);
  }
  CredFree(credential);
  return bytes;
}

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
    SECURITY_DESCRIPTOR* descriptor,
    std::vector<BYTE>* acl_buffer) {
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
  const DWORD sid_size = GetLengthSid(token_user->User.Sid);
  const DWORD acl_size =
      static_cast<DWORD>(sizeof(ACL) + sizeof(ACCESS_ALLOWED_ACE) -
                         sizeof(DWORD)) +
      sid_size;
  acl_buffer->resize(acl_size);
  auto* acl = reinterpret_cast<ACL*>(acl_buffer->data());
  if (!InitializeAcl(acl, acl_size, ACL_REVISION) ||
      !AddAccessAllowedAce(acl, ACL_REVISION, GENERIC_READ | GENERIC_WRITE,
                           token_user->User.Sid) ||
      !InitializeSecurityDescriptor(descriptor,
                                    SECURITY_DESCRIPTOR_REVISION) ||
      !SetSecurityDescriptorDacl(descriptor, TRUE, acl, FALSE)) {
    return false;
  }
  attributes->nLength = sizeof(SECURITY_ATTRIBUTES);
  attributes->lpSecurityDescriptor = descriptor;
  attributes->bInheritHandle = FALSE;
  return true;
}

void ServeSnapshots(const std::atomic<bool>& stopping) {
  SECURITY_ATTRIBUTES attributes{};
  SECURITY_DESCRIPTOR descriptor{};
  std::vector<BYTE> acl_buffer;
  if (!CreateCurrentUserSecurityAttributes(&attributes, &descriptor,
                                           &acl_buffer)) {
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
    if (call.method_name() == "readClaudeWindowsCredential") {
      const auto* arguments =
          std::get_if<flutter::EncodableMap>(call.arguments());
      if (arguments == nullptr) {
        result->Error("invalid_arguments", "Expected Claude credential options.");
        return;
      }
      const auto part_it = arguments->find(flutter::EncodableValue("part"));
      int64_t part = -3;
      if (part_it != arguments->end()) {
        if (const auto* value32 = std::get_if<int32_t>(&part_it->second)) {
          part = *value32;
        } else if (const auto* value64 = std::get_if<int64_t>(&part_it->second)) {
          part = *value64;
        }
      }
      std::string config_directory;
      const auto config_it =
          arguments->find(flutter::EncodableValue("configDir"));
      if (config_it != arguments->end() &&
          !std::holds_alternative<std::monostate>(config_it->second)) {
        const auto* value = std::get_if<std::string>(&config_it->second);
        if (value == nullptr || value->size() > 4 * UNICODE_STRING_MAX_CHARS ||
            value->find('\0') != std::string::npos) {
          result->Error("invalid_arguments", "Invalid Claude config directory.");
          return;
        }
        config_directory = *value;
      }
      if (part < -2 || part > 255) {
        result->Error("invalid_arguments", "Invalid Claude credential part.");
        return;
      }
      const auto target = ClaudeCredentialTarget(config_directory, part);
      if (!target) {
        result->Error("credential_read_failed", "Cannot resolve Claude profile.");
        return;
      }
      auto bytes = ReadClaudeWindowsCredential(*target);
      if (bytes) {
        result->Success(flutter::EncodableValue(std::move(*bytes)));
      } else {
        result->Success();
      }
      return;
    }
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
