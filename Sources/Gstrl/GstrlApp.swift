import AppKit
import SwiftUI
import Carbon.HIToolbox
import AVFoundation
import Speech

class AppDelegate: NSObject, NSApplicationDelegate {
    private var appState = AppState()
    private var coordinator: TrackingCoordinator?
    private var mainWindow: NSWindow?
    private var islandPanel: NSPanel?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        createMainWindow()
        createIslandPanel()
        requestAllPermissions()
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

    private func requestAllPermissions() {
        AVCaptureDevice.requestAccess(for: .video) { _ in }
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
        SFSpeechRecognizer.requestAuthorization { _ in }

        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
        }

        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
    }

    private func createMainWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 280),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Gstrl"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: MainStatusView(appState: appState, onToggle: { [weak self] in
            self?.toggleTracking()
        }, onFPSChanged: { [weak self] fps in
            self?.coordinator?.syncSettings()
        }))
        window.makeKeyAndOrderFront(nil)
        mainWindow = window
    }

    private func createIslandPanel() {
        guard let screen = NSScreen.main else { return }

        let panelSize = NSSize(width: 400, height: 100)
        let hasNotch = screen.safeAreaInsets.top > 0
        let offset: CGFloat = hasNotch ? screen.safeAreaInsets.top : 0
        let origin = NSPoint(
            x: screen.frame.midX - panelSize.width / 2,
            y: screen.frame.maxY - panelSize.height - offset
        )

        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.collectionBehavior = [
            .fullScreenAuxiliary,
            .stationary,
            .canJoinAllSpaces,
            .ignoresCycle
        ]

        let hostView = ClickThroughHostingView(rootView:
            DynamicIslandView(appState: appState, onToggle: { [weak self] in
                self?.toggleTracking()
            }, onTap: { [weak self] in
                self?.showWindow()
            })
        )
        hostView.frame = panel.contentView?.bounds ?? .zero
        hostView.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(hostView)

        panel.orderFrontRegardless()
        islandPanel = panel
    }

    private func createMenuBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "dot.radiowaves.left.and.right", accessibilityDescription: "Gstrl")

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle", action: #selector(toggleTracking), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Show Window", action: #selector(showWindow), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc private func showWindow() {
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleTracking() {
        if appState.isEnabled {
            coordinator?.stop()
            coordinator = nil
            appState.isEnabled = false
        } else {
            if !AXIsProcessTrusted() {
                let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
                AXIsProcessTrustedWithOptions(options)
                return
            }
            appState.isEnabled = true
            let coord = TrackingCoordinator(appState: appState)
            coord.start()
            coordinator = coord
            registerGlobalHotkey()
        }
    }

    private func registerGlobalHotkey() {
        // Only kill when Gstrl is focused
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == UInt16(kVK_Escape) {
                self?.coordinator?.emergencyKill()
                return nil
            }
            return event
        }
    }
}

final class ClickThroughHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@main
struct GstrlMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}
