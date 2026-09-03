#include "windows_secure_store.h"

#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <dpapi.h>

#include <cstring>
#include <optional>
#include <string>
#include <vector>

namespace {

constexpr wchar_t kEntropyDescription[] = L"AI Limit Status secure store";

const std::vector<uint8_t>* BytesArgument(
    const flutter::MethodCall<flutter::EncodableValue>& method_call) {
  const auto* arguments =
      std::get_if<flutter::EncodableMap>(method_call.arguments());
  if (arguments == nullptr) {
    return nullptr;
  }
  const auto iterator = arguments->find(flutter::EncodableValue("data"));
  if (iterator == arguments->end()) {
    return nullptr;
  }
  return std::get_if<std::vector<uint8_t>>(&iterator->second);
}

std::optional<std::vector<uint8_t>> Transform(const std::vector<uint8_t>& input,
                                              bool protect_data) {
  DATA_BLOB in_blob{};
  in_blob.cbData = static_cast<DWORD>(input.size());
  in_blob.pbData = const_cast<BYTE*>(input.data());
  DATA_BLOB out_blob{};
  const BOOL ok =
      protect_data
          ? CryptProtectData(&in_blob, kEntropyDescription, nullptr, nullptr,
                             nullptr, CRYPTPROTECT_UI_FORBIDDEN, &out_blob)
          : CryptUnprotectData(&in_blob, nullptr, nullptr, nullptr, nullptr,
                               CRYPTPROTECT_UI_FORBIDDEN, &out_blob);
  if (!ok || out_blob.pbData == nullptr) {
    return std::nullopt;
  }
  std::vector<uint8_t> output(out_blob.pbData, out_blob.pbData + out_blob.cbData);
  // Scrub decrypted plaintext before releasing the buffer.
  SecureZeroMemory(out_blob.pbData, out_blob.cbData);
  LocalFree(out_blob.pbData);
  return output;
}

}  // namespace

WindowsSecureStore::WindowsSecureStore(flutter::BinaryMessenger* messenger)
    : channel_(std::make_unique<
               flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "com.ailimitstatus/secure_store",
          &flutter::StandardMethodCodec::GetInstance())) {
  channel_->SetMethodCallHandler([](const auto& call, auto result) {
    const bool protect_data = call.method_name() == "protect";
    if (!protect_data && call.method_name() != "unprotect") {
      result->NotImplemented();
      return;
    }
    const auto* input = BytesArgument(call);
    if (input == nullptr) {
      result->Error("invalid_arguments", "Expected a 'data' byte list.");
      return;
    }
    auto output = Transform(*input, protect_data);
    if (!output) {
      result->Error("dpapi_failed",
                    "Windows Data Protection could not process the value.");
      return;
    }
    result->Success(flutter::EncodableValue(std::move(*output)));
  });
}

WindowsSecureStore::~WindowsSecureStore() = default;
