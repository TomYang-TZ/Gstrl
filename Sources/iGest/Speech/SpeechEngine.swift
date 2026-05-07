import Foundation
import Speech
import AVFoundation
import AppKit

final class SpeechEngine {
    private var recognizer: SFSpeechRecognizer?
    private var audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private(set) var isListening = false
    var onResult: ((String) -> Void)?

    init() {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    func startListening() {
        guard !isListening else { return }
        guard let recognizer, recognizer.isAvailable else {
            NSLog("iGest: Speech recognizer not available")
            return
        }

        isListening = true
        NSLog("iGest: Speech listening started")

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            NSLog("iGest: Audio engine failed: \(error)")
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
        guard isListening else { return }
        isListening = false

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        NSLog("iGest: Speech listening stopped")
    }

    func typeText(_ text: String) {
        DispatchQueue.main.async {
            for char in text {
                let chars = Array(String(char).utf16)
                guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else { continue }
                event.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: chars)
                event.post(tap: .cghidEventTap)
                guard let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else { continue }
                up.post(tap: .cghidEventTap)
                usleep(10000)
            }
        }
    }
}
