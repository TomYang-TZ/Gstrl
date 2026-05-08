import Foundation
import Speech
import AVFoundation
import AppKit

final class SpeechEngine {
    private var recognizer: SFSpeechRecognizer?
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private(set) var isListening = false
    private let queue = DispatchQueue(label: "com.gstrl.speech")
    var onResult: ((String) -> Void)?

    init() {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    func startListening() {
        queue.sync { self._startListening() }
    }

    private func _startListening() {
        guard !isListening else { return }
        guard let recognizer, recognizer.isAvailable else {
            NSLog("Gstrl: Speech recognizer not available")
            return
        }

        isListening = true

        let engine = AVAudioEngine()
        self.audioEngine = engine

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else {
            isListening = false
            return
        }
        request.shouldReportPartialResults = true

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        guard format.sampleRate > 0 && format.channelCount > 0 else {
            NSLog("Gstrl: Audio input format invalid (rate=%.0f ch=%d) — no mic available?", format.sampleRate, format.channelCount)
            isListening = false
            return
        }

        NSLog("Gstrl: Speech starting — input: %.0fHz, %d ch", format.sampleRate, format.channelCount)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            NSLog("Gstrl: Audio engine failed: \(error)")
            inputNode.removeTap(onBus: 0)
            isListening = false
            return
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            if let result {
                let text = result.bestTranscription.formattedString
                self?.onResult?(text)
            }
            if error != nil || (result?.isFinal ?? false) {
                self?.stopListening()
            }
        }
    }

    func stopListening() {
        queue.sync { self._stopListening() }
    }

    private func _stopListening() {
        guard isListening else { return }
        isListening = false

        if let engine = audioEngine {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        NSLog("Gstrl: Speech listening stopped")
    }

    func deleteChars(_ count: Int) {
        DispatchQueue.main.async {
            for _ in 0..<count {
                guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 0x33, keyDown: true) else { continue }
                down.flags = []
                down.post(tap: .cghidEventTap)
                guard let up = CGEvent(keyboardEventSource: nil, virtualKey: 0x33, keyDown: false) else { continue }
                up.flags = []
                up.post(tap: .cghidEventTap)
                usleep(10000)
            }
        }
    }

    func typeText(_ text: String) {
        DispatchQueue.main.async {
            for char in text {
                let chars = Array(String(char).utf16)
                // Use virtualKey 49 (space) as dummy — unicode string overrides actual character
                guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 49, keyDown: true) else { continue }
                event.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: chars)
                event.flags = []
                event.post(tap: .cghidEventTap)
                guard let up = CGEvent(keyboardEventSource: nil, virtualKey: 49, keyDown: false) else { continue }
                up.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: chars)
                up.flags = []
                up.post(tap: .cghidEventTap)
                usleep(10000)
            }
        }
    }
}
