import SwiftUI

#if os(macOS)
import AppKit
#endif

@main
struct VerbatimApp: App {
#if os(macOS)
    init() {
        NSWindow.allowsAutomaticWindowTabbing = true
    }
#endif

    var body: some Scene {
        WindowGroup {
            ContentView()
#if os(macOS)
                .background(WindowTabConfigurator())
#endif
        }
        .commands {
#if os(macOS)
            CommandGroup(after: .newItem) {
                Button("New Tab") {
                    WindowTabController.openNewTab()
                }
                .keyboardShortcut("t", modifiers: [.command])
            }
#endif
        }
    }
}

#if os(macOS)
private enum WindowTabController {
    static func openNewTab() {
        NSApp.sendAction(#selector(NSWindow.newWindowForTab(_:)), to: nil, from: nil)
    }
}

private struct WindowTabConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        configureWindow(for: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        configureWindow(for: nsView)
    }

    private func configureWindow(for view: NSView) {
        DispatchQueue.main.async {
            view.window?.tabbingMode = .preferred
        }
    }
}
#endif
