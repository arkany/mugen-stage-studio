import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var mainWindowController: MainWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 applicationDidFinishLaunching started")
        
        // Set up main menu
        setupMainMenu()
        print("✅ Menu setup complete")
        
        // Create and show main window
        mainWindowController = MainWindowController()
        print("✅ MainWindowController created")
        
        mainWindowController?.showWindow(nil)
        print("✅ showWindow called")
        
        if let window = mainWindowController?.window {
            print("✅ Window exists: \(window)")
            print("   - isVisible: \(window.isVisible)")
            print("   - frame: \(window.frame)")
        } else {
            print("❌ Window is nil!")
        }
        
        // Activate the app
        NSApp.activate(ignoringOtherApps: true)
        print("✅ App activated")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    // MARK: - Menu Setup
    
    private func setupMainMenu() {
        let mainMenu = NSMenu()
        
        // App menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        
        appMenu.addItem(withTitle: "About MUGEN Stage Studio", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit MUGEN Stage Studio", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        
        // File menu
        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu
        
        fileMenu.addItem(withTitle: "Import Image...", action: #selector(importImageAction), keyEquivalent: "o")
        fileMenu.addItem(withTitle: "Export Stage...", action: #selector(exportStageAction), keyEquivalent: "e")
        
        // View menu
        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu
        
        viewMenu.addItem(withTitle: "Zoom In", action: #selector(zoomInAction), keyEquivalent: "+")
        viewMenu.addItem(withTitle: "Zoom Out", action: #selector(zoomOutAction), keyEquivalent: "-")
        viewMenu.addItem(withTitle: "Zoom to Fit", action: #selector(zoomToFitAction), keyEquivalent: "0")
        viewMenu.addItem(withTitle: "Actual Size", action: #selector(zoomActualSizeAction), keyEquivalent: "1")
        
        // Window menu
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu
        
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.zoom(_:)), keyEquivalent: "")
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        
        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
    }
    
    // MARK: - Menu Actions
    
    @objc func importImageAction(_ sender: Any?) {
        mainWindowController?.importImage(sender)
    }
    
    @objc func exportStageAction(_ sender: Any?) {
        mainWindowController?.exportStage(sender)
    }
    
    @objc func zoomInAction(_ sender: Any?) {
        mainWindowController?.zoomIn(sender)
    }
    
    @objc func zoomOutAction(_ sender: Any?) {
        mainWindowController?.zoomOut(sender)
    }
    
    @objc func zoomToFitAction(_ sender: Any?) {
        mainWindowController?.zoomToFit(sender)
    }
    
    @objc func zoomActualSizeAction(_ sender: Any?) {
        mainWindowController?.zoomActualSize(sender)
    }
}