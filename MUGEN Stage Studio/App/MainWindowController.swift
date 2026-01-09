import Cocoa

class MainWindowController: NSWindowController {
    
    private var mainViewController: MainViewController!
    
    convenience init() {
        print("🪟 MainWindowController init started")
        
        // Create window programmatically
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        print("✅ NSWindow created")
        
        self.init(window: window)
        print("✅ self.init(window:) called")
        
        configureWindow()
        setupViewController()
        print("✅ MainWindowController init complete")
    }
    
    private func configureWindow() {
        guard let window = window else { return }
        
        window.title = "MUGEN Stage Studio"
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        window.backgroundColor = NSColor.windowBackgroundColor
        window.minSize = NSSize(width: 900, height: 600)
        window.collectionBehavior = [.fullScreenPrimary, .managed]
        window.center()
        
        // Set window delegate
        window.delegate = self
        
        // Make window visible
        window.makeKeyAndOrderFront(nil)
    }
    
    private func setupViewController() {
        print("📦 setupViewController started")
        mainViewController = MainViewController()
        print("✅ MainViewController created")
        window?.contentViewController = mainViewController
        print("✅ contentViewController assigned")
    }
    
    // MARK: - Actions
    
    @objc func importImage(_ sender: Any?) {
        mainViewController.importImage()
    }
    
    @objc func exportStage(_ sender: Any?) {
        mainViewController.exportStage()
    }
    
    @objc func zoomIn(_ sender: Any?) {
        mainViewController.zoomIn()
    }
    
    @objc func zoomOut(_ sender: Any?) {
        mainViewController.zoomOut()
    }
    
    @objc func zoomToFit(_ sender: Any?) {
        mainViewController.zoomToFit()
    }
    
    @objc func zoomActualSize(_ sender: Any?) {
        mainViewController.zoomActualSize()
    }
}

// MARK: - NSWindowDelegate

extension MainWindowController: NSWindowDelegate {
    
    func windowWillEnterFullScreen(_ notification: Notification) {
        // Prepare for fullscreen
    }
    
    func windowDidEnterFullScreen(_ notification: Notification) {
        // Handle fullscreen entry
    }
    
    func windowWillExitFullScreen(_ notification: Notification) {
        // Prepare to exit fullscreen
    }
    
    func windowDidExitFullScreen(_ notification: Notification) {
        // Handle fullscreen exit
    }
}
