import AppKit
import SwiftUI
import Carbon.HIToolbox

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var appState = AppState()
    private var coordinator: TrackingCoordinator?
    private var mapper = PolynomialMapper()
    private var calibrationController = CalibrationWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "iGest")
        }

        buildMenu()
    }

    private func buildMenu() {
        let menu = NSMenu()

        let toggleItem = NSMenuItem(title: "Enable iGest", action: #selector(toggleTracking), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let recalItem = NSMenuItem(title: "Recalibrate", action: #selector(recalibrate), keyEquivalent: "")
        recalItem.target = self
        menu.addItem(recalItem)

        let sensitivityMenu = NSMenu()
        for level in AppState.Sensitivity.allCases {
            let item = NSMenuItem(title: level.rawValue.capitalized, action: #selector(setSensitivity(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = level
            sensitivityMenu.addItem(item)
        }
        let sensitivityItem = NSMenuItem(title: "Sensitivity", action: nil, keyEquivalent: "")
        sensitivityItem.submenu = sensitivityMenu
        menu.addItem(sensitivityItem)

        menu.addItem(.separator())

        let killItem = NSMenuItem(title: "Kill: ⎋ Escape", action: nil, keyEquivalent: "")
        killItem.isEnabled = false
        menu.addItem(killItem)

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
            startTracking()
        }
    }

    @objc private func recalibrate() {
        coordinator?.stop()
        coordinator = nil
        openCalibration()
    }

    @objc private func setSensitivity(_ sender: NSMenuItem) {
        guard let level = sender.representedObject as? AppState.Sensitivity else { return }
        appState.sensitivity = level
        coordinator?.updateSensitivity()
    }

    private func startTracking() {
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            appState.isEnabled = false
            updateIcon()
            return
        }

        if !mapper.load() {
            openCalibration()
            return
        }

        appState.isCalibrated = true
        let coord = TrackingCoordinator(appState: appState, mapper: mapper)
        coord.start()
        coordinator = coord
        updateIcon()
        registerGlobalHotkey()
    }

    private func openCalibration() {
        let tempGazeTracker = GazeTracker(mapper: mapper)
        let tempCamera = CameraManager()
        calibrationController.show(
            mapper: mapper,
            gazeTracker: tempGazeTracker,
            cameraManager: tempCamera
        ) { [weak self] in
            guard let self else { return }
            self.appState.isCalibrated = true
            let coord = TrackingCoordinator(appState: self.appState, mapper: self.mapper)
            coord.start()
            self.coordinator = coord
            self.updateIcon()
            self.registerGlobalHotkey()
        }
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        let name: String
        if !appState.isEnabled {
            name = "eye.slash"
        } else {
            switch appState.trackingState {
            case .inactive: name = "eye"
            case .tracking, .pinching: name = "eye.fill"
            }
        }
        button.image = NSImage(systemSymbolName: name, accessibilityDescription: "iGest")
    }

    private func registerGlobalHotkey() {
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == UInt16(kVK_Escape) {
                self?.coordinator?.emergencyKill()
                self?.appState.isEnabled = false
                self?.updateIcon()
            }
        }
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == UInt16(kVK_Escape) {
                self?.coordinator?.emergencyKill()
                self?.appState.isEnabled = false
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
        if let recalItem = menu.item(at: 2) {
            recalItem.isEnabled = appState.isEnabled
        }
        if let sensitivityItem = menu.item(at: 3),
           let subMenu = sensitivityItem.submenu {
            for item in subMenu.items {
                if let level = item.representedObject as? AppState.Sensitivity {
                    item.state = (level == appState.sensitivity) ? .on : .off
                }
            }
        }
    }
}

@main
struct iGestMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
