import AppKit
import SwiftUI
import Carbon.HIToolbox

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var appState = AppState()
    private var coordinator: TrackingCoordinator?
    private var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "hand.point.up", accessibilityDescription: "iGest")
        }

        buildMenu()
        createMainWindow()
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.stop()
        coordinator = nil
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    private func createMainWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 180),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "iGest"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: MainStatusView(appState: appState, onToggle: { [weak self] in
            self?.toggleTracking()
        }))
        window.makeKeyAndOrderFront(nil)
        mainWindow = window
    }

    private func buildMenu() {
        let menu = NSMenu()

        let toggleItem = NSMenuItem(title: "Enable iGest", action: #selector(toggleTracking), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        menu.delegate = self
        statusItem.menu = menu
    }

    @objc private func toggleTracking() {
        if appState.isEnabled {
            coordinator?.stop()
            coordinator = nil
            appState.isEnabled = false
            updateIcon()
        } else {
            appState.isEnabled = true
            let coord = TrackingCoordinator(appState: appState)
            coord.start()
            coordinator = coord
            updateIcon()
            registerGlobalHotkey()
        }
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        let name: String
        if !appState.isEnabled {
            name = "hand.point.up"
        } else {
            switch appState.trackingState {
            case .inactive: name = "hand.raised"
            case .tracking: name = "hand.raised.fill"
            case .pinching: name = "hand.pinch.fill"
            }
        }
        button.image = NSImage(systemSymbolName: name, accessibilityDescription: "iGest")
    }

    private func registerGlobalHotkey() {
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == UInt16(kVK_Escape) {
                self?.coordinator?.emergencyKill()
                self?.updateIcon()
            }
        }
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == UInt16(kVK_Escape) {
                self?.coordinator?.emergencyKill()
                self?.updateIcon()
                return nil
            }
            return event
        }
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        if let toggleItem = menu.item(at: 0) {
            toggleItem.title = appState.isEnabled ? "Disable iGest" : "Enable iGest"
        }
    }
}

@main
struct iGestMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}
