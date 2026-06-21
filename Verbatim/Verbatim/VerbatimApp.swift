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
    private static var tabWindowControllers: [VerbatimTabWindowController] = []

    static func openNewTab() {
        guard let currentWindow = NSApp.keyWindow ?? NSApp.mainWindow else {
            let controller = makeTabWindowController()
            tabWindowControllers.append(controller)
            controller.showWindow(nil)
            return
        }

        configure(currentWindow)

        let controller = makeTabWindowController()
        guard let tabWindow = controller.window else { return }

        tabWindowControllers.append(controller)
        currentWindow.addTabbedWindow(tabWindow, ordered: .above)
        tabWindow.makeKeyAndOrderFront(nil)
    }

    static func close(_ controller: VerbatimTabWindowController) {
        tabWindowControllers.removeAll { $0 === controller }
    }

    private static func makeTabWindowController() -> VerbatimTabWindowController {
        let hostingController = NSHostingController(rootView: ContentView())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Verbatim"
        window.contentViewController = hostingController
        window.minSize = NSSize(width: 980, height: 620)
        configure(window)

        let controller = VerbatimTabWindowController(window: window)
        window.delegate = controller
        return controller
    }

    static func configure(_ window: NSWindow) {
        window.tabbingMode = .preferred
        window.tabbingIdentifier = "Verbatim.TranscriptionWorkspace"
    }
}

private final class VerbatimTabWindowController: NSWindowController, NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        WindowTabController.close(self)
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
            guard let window = view.window else { return }
            WindowTabController.configure(window)
        }
    }
}
#endif
