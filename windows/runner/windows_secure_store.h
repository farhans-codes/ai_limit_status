#ifndef RUNNER_WINDOWS_SECURE_STORE_H_
#define RUNNER_WINDOWS_SECURE_STORE_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <memory>

// Encrypts and decrypts small secrets with the current user's DPAPI key so
// Dart can persist, for example, a pasted claude.ai session key without
// writing it to disk in clear text.
class WindowsSecureStore {
 public:
  explicit WindowsSecureStore(flutter::BinaryMessenger* messenger);
  ~WindowsSecureStore();

 private:
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_WINDOWS_SECURE_STORE_H_
