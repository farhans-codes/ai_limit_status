#ifndef RUNNER_WINDOWS_NOTIFICATION_SOUND_H_
#define RUNNER_WINDOWS_NOTIFICATION_SOUND_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <memory>

class WindowsNotificationSound {
 public:
  explicit WindowsNotificationSound(flutter::BinaryMessenger* messenger);
  ~WindowsNotificationSound();

 private:
  bool Play() const;

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_WINDOWS_NOTIFICATION_SOUND_H_
