import Cocoa

// Create the application
let app = NSApplication.shared

// Create and set the app delegate
let delegate = AppDelegate()
app.delegate = delegate

// Run the application
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
