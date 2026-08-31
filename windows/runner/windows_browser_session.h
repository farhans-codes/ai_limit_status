#ifndef RUNNER_WINDOWS_BROWSER_SESSION_H_
#define RUNNER_WINDOWS_BROWSER_SESSION_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <memory>
#include <string>
#include <vector>

bool IsWindowsBrowserSessionHostInvocation(
    const std::vector<std::string>& arguments);
int RunWindowsBrowserSessionHost();

class WindowsBrowserSession {
 public:
  explicit WindowsBrowserSession(flutter::BinaryMessenger* messenger);
  ~WindowsBrowserSession();

 private:
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_WINDOWS_BROWSER_SESSION_H_
