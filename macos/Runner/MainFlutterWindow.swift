import Cocoa
import FlutterMacOS
import ServiceManagement

class MainFlutterWindow: NSPanel {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    flutterViewController.backgroundColor = .clear
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    isOpaque = false
    backgroundColor = .clear
    titlebarAppearsTransparent = true

    let glassView = NSVisualEffectView(frame: flutterViewController.view.bounds)
    glassView.autoresizingMask = [.width, .height]
    glassView.blendingMode = .behindWindow
    glassView.material = .popover
    glassView.state = .active
    flutterViewController.view.addSubview(glassView, positioned: .below, relativeTo: nil)

    RegisterGeneratedPlugins(registry: flutterViewController)
    MacStatusBarController.install(
      panel: self,
      messenger: flutterViewController.engine.binaryMessenger
    )
    MacStartupController.install(
      messenger: flutterViewController.engine.binaryMessenger
    )

    super.awakeFromNib()
  }
}

private final class MacStartupController {
  private static var shared: MacStartupController?

  static func install(messenger: FlutterBinaryMessenger) {
    shared = MacStartupController(messenger: messenger)
  }

  private let channel: FlutterMethodChannel

  private init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "com.ailimitstatus/startup",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(macOS 13.0, *) else {
      if call.method == "isEnabled" {
        result(false)
      } else {
        result("unsupported")
      }
      return
    }

    switch call.method {
    case "isEnabled":
      result(SMAppService.mainApp.status == .enabled)
    case "setEnabled":
      guard
        let arguments = call.arguments as? [String: Any],
        let shouldEnable = arguments["enabled"] as? Bool
      else {
        result(FlutterError(code: "invalid_arguments", message: nil, details: nil))
        return
      }
      updateStartupRegistration(shouldEnable, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @available(macOS 13.0, *)
  private func updateStartupRegistration(
    _ shouldEnable: Bool,
    result: @escaping FlutterResult
  ) {
    let service = SMAppService.mainApp
    do {
      if shouldEnable {
        if service.status == .requiresApproval {
          SMAppService.openSystemSettingsLoginItems()
          result("requiresApproval")
          return
        }
        if service.status != .enabled {
          try service.register()
        }
      } else if service.status != .notRegistered {
        try service.unregister()
      }

      switch service.status {
      case .enabled:
        result("enabled")
      case .requiresApproval:
        SMAppService.openSystemSettingsLoginItems()
        result("requiresApproval")
      case .notRegistered:
        result("disabled")
      case .notFound:
        result("failed")
      @unknown default:
        result("failed")
      }
    } catch {
      result(
        FlutterError(
          code: "startup_registration_failed",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }
}

private final class MacStatusBarController: NSObject {
  private static var shared: MacStatusBarController?

  static func install(panel: NSPanel, messenger: FlutterBinaryMessenger) {
    shared = MacStatusBarController(panel: panel, messenger: messenger)
  }

  private weak var panel: NSPanel?
  private let channel: FlutterMethodChannel
  private var statusItem: NSStatusItem?
  private var anchorPoint: NSPoint?
  private var codexImage: NSImage?
  private var claudeImage: NSImage?
  private var appImage: NSImage?
  private let contextMenu = NSMenu()

  private init(panel: NSPanel, messenger: FlutterBinaryMessenger) {
    self.panel = panel
    channel = FlutterMethodChannel(
      name: "com.ailimitstatus/status_item",
      binaryMessenger: messenger
    )
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize":
      guard let arguments = call.arguments as? [String: Any] else {
        result(FlutterError(code: "invalid_arguments", message: nil, details: nil))
        return
      }
      codexImage = templateImage(from: arguments["codexSvg"] as? String)
      claudeImage = templateImage(from: arguments["claudeSvg"] as? String)
      appImage = NSImage(named: NSImage.applicationIconName)
      configureMenu(arguments)
      createStatusItemIfNeeded()
      updateStatusItem(arguments)
      result(nil)
    case "update":
      guard let arguments = call.arguments as? [String: Any] else {
        result(FlutterError(code: "invalid_arguments", message: nil, details: nil))
        return
      }
      updateStatusItem(arguments)
      result(nil)
    case "show":
      result(nil)
      DispatchQueue.main.async { [weak self] in
        self?.showPanelWithGuard()
      }
    case "destroy":
      if let statusItem {
        NSStatusBar.system.removeStatusItem(statusItem)
      }
      statusItem = nil
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func createStatusItemIfNeeded() {
    guard statusItem == nil else { return }

    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    if let button = item.button {
      button.target = self
      button.action = #selector(statusItemPressed)
      button.sendAction(on: [.leftMouseUp, .rightMouseUp])
      button.imagePosition = .noImage
    }
    statusItem = item
  }

  private func configureMenu(_ arguments: [String: Any]) {
    contextMenu.removeAllItems()
    addMenuItem(
      title: arguments["openLabel"] as? String ?? "",
      action: #selector(openDetails)
    )
    addMenuItem(
      title: arguments["refreshLabel"] as? String ?? "",
      action: #selector(refreshUsage)
    )
    contextMenu.addItem(.separator())
    addMenuItem(
      title: arguments["quitLabel"] as? String ?? "",
      action: #selector(quitApp)
    )
  }

  private func addMenuItem(title: String, action: Selector) {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
    item.target = self
    contextMenu.addItem(item)
  }

  private func updateStatusItem(_ arguments: [String: Any]) {
    guard let button = statusItem?.button else { return }
    let codexValue = arguments["codexValue"] as? String
    let claudeValue = arguments["claudeValue"] as? String
    button.attributedTitle = statusTitle(
      codexValue: codexValue,
      claudeValue: claudeValue
    )
    if let tooltip = arguments["tooltip"] as? String {
      button.toolTip = tooltip
    }
  }

  private func statusTitle(codexValue: String?, claudeValue: String?) -> NSAttributedString {
    let title = NSMutableAttributedString()
    if let codexValue, let codexImage {
      title.append(attachment(for: codexImage))
      title.append(statusText(" \(codexValue)"))
    }
    if codexValue != nil, claudeValue != nil {
      title.append(statusText("   "))
    }
    if let claudeValue, let claudeImage {
      title.append(attachment(for: claudeImage))
      title.append(statusText(" \(claudeValue)"))
    }
    if codexValue == nil, claudeValue == nil, let appImage {
      title.append(attachment(for: appImage))
    }
    return title
  }

  private func statusText(_ value: String) -> NSAttributedString {
    NSAttributedString(
      string: value,
      attributes: [
        .font: NSFont.monospacedDigitSystemFont(ofSize: 13.5, weight: .semibold),
        .foregroundColor: NSColor.labelColor,
        .baselineOffset: -1,
      ]
    )
  }

  private func attachment(for image: NSImage) -> NSAttributedString {
    let attachment = NSTextAttachment()
    attachment.image = tintedStatusImage(image)
    attachment.bounds = NSRect(x: 0, y: -5, width: 17, height: 17)
    return NSAttributedString(attachment: attachment)
  }

  private func tintedStatusImage(_ source: NSImage) -> NSImage {
    let size = NSSize(width: 17, height: 17)
    let image = NSImage(size: size)
    image.lockFocus()
    source.draw(in: NSRect(origin: .zero, size: size))
    NSColor.labelColor.setFill()
    NSRect(origin: .zero, size: size).fill(using: .sourceAtop)
    image.unlockFocus()
    return image
  }

  private func templateImage(from svg: String?) -> NSImage? {
    guard let svg, let data = svg.data(using: .utf8), let image = NSImage(data: data) else {
      return nil
    }
    image.isTemplate = true
    image.size = NSSize(width: 17, height: 17)
    return image
  }

  @objc private func statusItemPressed() {
    anchorPoint = NSEvent.mouseLocation
    if NSApp.currentEvent?.type == .rightMouseUp {
      if let button = statusItem?.button {
        contextMenu.popUp(
          positioning: nil,
          at: NSPoint(x: 0, y: button.bounds.minY),
          in: button
        )
      }
      return
    }
    togglePanel()
  }

  @objc private func openDetails() {
    showPanelWithGuard()
  }

  @objc private func refreshUsage() {
    channel.invokeMethod("refresh", arguments: nil)
  }

  @objc private func quitApp() {
    channel.invokeMethod("quit", arguments: nil)
  }

  private func togglePanel() {
    guard let panel else { return }
    if panel.isVisible {
      panel.orderOut(nil)
    } else {
      showPanelWithGuard()
    }
  }

  private func showPanelWithGuard() {
    channel.invokeMethod("willShow", arguments: nil) { [weak self] _ in
      self?.showPanel()
    }
  }

  private func showPanel() {
    guard
      let panel,
      let anchorPoint = anchorPoint ?? statusItem?.button?.window?.frame.center,
      let screen = NSScreen.screens.first(where: { $0.frame.contains(anchorPoint) })
        ?? NSScreen.main
    else { return }

    let visibleFrame = screen.visibleFrame
    let panelSize = panel.frame.size
    let preferredX = anchorPoint.x - panelSize.width / 2
    let x = min(
      max(preferredX, visibleFrame.minX + 6),
      visibleFrame.maxX - panelSize.width - 6
    )
    let preferredY = visibleFrame.maxY - panelSize.height - 6
    let y = max(preferredY, visibleFrame.minY + 6)

    panel.setFrameOrigin(NSPoint(x: x, y: y))
    panel.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }
}

private extension NSRect {
  var center: NSPoint {
    NSPoint(x: midX, y: midY)
  }
}
