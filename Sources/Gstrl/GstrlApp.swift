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

        // Screen recording
        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
        }

        // Accessibility
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
    }

    private func createMainWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 500),
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
        }, onStopSpeaking: { [weak self] in
            self?.coordinator?.stopSpeaking()
        }))
        window.makeKeyAndOrderFront(nil)
        mainWindow = window
    }

    private func createIslandPanel() {
        guard let screen = NSScreen.main else { return }

        let panelSize = NSSize(width: 300, height: 200)
        let hasNotch = screen.safeAreaInsets.top > 0
        let origin: NSPoint
        if hasNotch {
            let notchWidth: CGFloat = 180
            let notchLeftEdge = screen.frame.midX - notchWidth / 2
            origin = NSPoint(
                x: notchLeftEdge - panelSize.width - 4,
                y: screen.frame.maxY - panelSize.height
            )
        } else {
            origin = NSPoint(
                x: screen.frame.midX - panelSize.width / 2,
                y: screen.frame.maxY - panelSize.height
            )
        }

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
        panel.ignoresMouseEvents = true
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
            }, onAgentDismiss: { [weak self] in
                self?.coordinator?.clearAgentSession()
                self?.coordinator?.stopSpeaking()
            }, onStopSpeaking: { [weak self] in
                self?.coordinator?.stopSpeaking()
            }, onAgentTerminate: { [weak self] in
                self?.coordinator?.terminateAgent()
            })
        )
        hostView.wantsLayer = true
        hostView.layer?.isOpaque = false
        hostView.layer?.backgroundColor = .clear
        hostView.appState = appState
        panel.contentView = hostView

        panel.orderFrontRegardless()
        islandPanel = panel

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.repositionIsland()
        }
    }

    private func repositionIsland() {
        guard let panel = islandPanel, let screen = NSScreen.main else { return }
        let panelSize = panel.frame.size
        let hasNotch = screen.safeAreaInsets.top > 0
        let origin: NSPoint
        if hasNotch {
            let notchWidth: CGFloat = 180
            let notchLeftEdge = screen.frame.midX - notchWidth / 2
            origin = NSPoint(
                x: notchLeftEdge - panelSize.width - 4,
                y: screen.frame.maxY - panelSize.height
            )
        } else {
            origin = NSPoint(
                x: screen.frame.midX - panelSize.width / 2,
                y: screen.frame.maxY - panelSize.height
            )
        }
        panel.setFrameOrigin(origin)
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
    private var monitor: Any?

    var appState: AppState?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window, monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self, weak window] event in
            guard let self, let window else { return }
            let mouseScreen = NSEvent.mouseLocation
            let windowFrame = window.frame
            let height = self.appState?.islandHeight ?? 36
            let islandFrame = NSRect(
                x: windowFrame.midX - 140,
                y: windowFrame.maxY - height,
                width: 280,
                height: height
            )
            let overIsland = islandFrame.contains(mouseScreen)
            if overIsland != !window.ignoresMouseEvents {
                window.ignoresMouseEvents = !overIsland
            }
        }
    }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
    }
}


@main
struct GstrlMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)

        let mainMenu = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Quit Gstrl", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        app.mainMenu = mainMenu
        app.run()
    }
}
