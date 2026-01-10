import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Dark title bar to match app theme
    self.backgroundColor = NSColor.black
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)

    super.awakeFromNib()
  }

  // Ensure window can become key window (required for keyboard input)
  override var canBecomeKey: Bool {
    return true
  }

  // Ensure window can become main window
  override var canBecomeMain: Bool {
    return true
  }

  // Accept first responder for keyboard events
  override var acceptsFirstResponder: Bool {
    return true
  }
}
