import SwiftUI
import Carbon.HIToolbox

@main
struct iGestApp: App {
    @State private var appState = AppState()
    @State private var coordinator: TrackingCoordinator?
    @State private var mapper = PolynomialMapper()
    @State private var calibrationController = CalibrationWindowController()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(appState)
        } label: {
            Image(systemName: menuBarIcon)
        }
        .onChange(of: appState.isEnabled) { _, enabled in
            if enabled {
                startTracking()
            } else {
                coordinator?.stop()
                coordinator = nil
            }
        }
        .onChange(of: appState.sensitivity) { _, _ in
            coordinator?.updateSensitivity()
        }
    }

    private var menuBarIcon: String {
        guard appState.isEnabled else { return "eye.slash" }
        switch appState.trackingState {
        case .inactive: return "eye"
        case .tracking, .pinching: return "eye.fill"
        }
    }

    private func startTracking() {
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            appState.isEnabled = false
            return
        }

        if !mapper.load() {
            let tempGazeTracker = GazeTracker(mapper: mapper)
            let tempCamera = CameraManager()
            calibrationController.show(
                mapper: mapper,
                gazeTracker: tempGazeTracker,
                cameraManager: tempCamera
            ) {
                appState.isCalibrated = true
                let coord = TrackingCoordinator(appState: appState, mapper: mapper)
                coord.start()
                coordinator = coord
                registerGlobalHotkey()
            }
            return
        }

        appState.isCalibrated = true
        let coord = TrackingCoordinator(appState: appState, mapper: mapper)
        coord.start()
        coordinator = coord
        registerGlobalHotkey()
    }

    private func registerGlobalHotkey() {
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                coordinator?.emergencyKill()
                appState.isEnabled = false
            }
        }
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                coordinator?.emergencyKill()
                appState.isEnabled = false
                return nil
            }
            return event
        }
    }
}
