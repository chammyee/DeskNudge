import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Persist on SIGTERM (logout / `kill`) as well as normal quit.
let sigterm = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
sigterm.setEventHandler {
    Store.shared.saveNow()
    NSApp.terminate(nil)
}
sigterm.resume()
signal(SIGTERM, SIG_IGN)

app.run()
