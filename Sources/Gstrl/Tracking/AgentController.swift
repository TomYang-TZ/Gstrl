import Foundation
import AVFoundation
import AppKit
import Speech

final class AgentController {
    private let speechEngine = SpeechEngine()
    private(set) var startTime: Date?
    private(set) var isActive = false
    private(set) var isProcessing = false
    private let holdDuration: TimeInterval = 1.0
    private let silenceTimeout: TimeInterval = 3.0

    private var transcribedText = ""
    private var lastUpdateTime: Date?
    private var silenceTimer: DispatchWorkItem?
    private var ttsProcess: Process?
    private var claudeProcess: Process?
    private(set) var sessionId: String?

    var onStateChanged: ((String, Double, AppState.ProgressMode) -> Void)?
    var onTranscriptUpdate: ((String) -> Void)?
    var onSilenceReset: (() -> Void)?
    var onResponse: ((String, String, String?, Int, Int, Double, [(tool: String, summary: String)]) -> Void)?
    var onSelectionCaptured: ((Int) -> Void)?
    var onSpeakingChanged: ((Bool) -> Void)?
    var onThinkingUpdate: ((String) -> Void)?
    var onActionUpdate: ((String, String) -> Void)?

    func reset() {
        if startTime != nil || isActive {
            startTime = nil
            silenceTimer?.cancel()
            silenceTimer = nil
            if isActive && !isProcessing {
                speechEngine.stopListening()
            }
            isActive = false
            transcribedText = ""
            lastUpdateTime = nil
        }
    }

    struct Status {
        let label: String
        let progress: Double
        let progressMode: AppState.ProgressMode
        let activated: Bool
    }

    func process() -> Status {
        if startTime == nil { startTime = Date() }

        let elapsed = Date().timeIntervalSince(startTime!)

        if !isActive && !isProcessing {
            if elapsed >= holdDuration {
                activate()
                return Status(label: "🤖 Listening...", progress: 0, progressMode: .countdown, activated: true)
            }
            let progress = min(1.0, elapsed / holdDuration)
            return Status(label: "🤖 Agent", progress: progress, progressMode: .countdown, activated: false)
        }

        if isProcessing {
            return Status(label: "🤖 Thinking...", progress: 0, progressMode: .countdown, activated: true)
        }

        return Status(label: "🤖 Listening...", progress: 0, progressMode: .countdown, activated: true)
    }

    private func activate() {
        isActive = true
        transcribedText = ""
        lastUpdateTime = nil
        silenceTimer?.cancel()

        onTranscriptUpdate?("")
        onStateChanged?("🤖 Listening...", 0, .countdown)

        speechEngine.onResult = { [weak self] text in
            DispatchQueue.main.async {
                self?.handleSpeechResult(text)
            }
        }
        speechEngine.startListening()

        // Safety timeout: if no speech after 30s, cancel
        let timeout = DispatchWorkItem { [weak self] in
            guard let self, self.isActive, self.transcribedText.isEmpty else { return }
            self.cancel()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: timeout)
    }

    func cancel() {
        silenceTimer?.cancel()
        silenceTimer = nil
        speechEngine.stopListening()
        isActive = false
        isProcessing = false
        transcribedText = ""
        onStateChanged?("", 0, .countdown)
        onTranscriptUpdate?("")
    }

    func terminateAgent() {
        if let p = claudeProcess, p.isRunning {
            p.terminate()
        }
        claudeProcess = nil
        isProcessing = false
        isActive = false
        onStateChanged?("", 0, .countdown)
        onTranscriptUpdate?("")
    }

    func clearSession() {
        if let sid = sessionId {
            try? FileManager.default.removeItem(atPath: "/tmp/gstrl/\(sid)")
        }
        sessionId = nil
        imageCount = 0
    }

    func handsReleased() {
        guard isActive, !isProcessing else { return }
        if transcribedText.isEmpty {
            cancel()
        } else {
            // Submit whatever was transcribed immediately
            silenceTimer?.cancel()
            submitToAgent()
        }
    }

    private func handleSpeechResult(_ text: String) {
        guard isActive else { return }
        transcribedText = text
        lastUpdateTime = Date()

        onTranscriptUpdate?(text)
        onSilenceReset?()

        silenceTimer?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.submitToAgent()
        }
        silenceTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + silenceTimeout, execute: work)
    }

    private func submitToAgent() {
        guard isActive, !transcribedText.isEmpty else { return }

        let query = transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        isActive = false
        isProcessing = true
        speechEngine.stopListening()

        onStateChanged?("🤖 Thinking...", 0, .countdown)

        // Save clipboard image BEFORE captureSelection (which overwrites clipboard)
        let screenshotPath = saveClipboardImage()

        // Capture selected text as context via Cmd+C
        let selectedText = captureSelection()
        if let sel = selectedText {
            let lineCount = sel.components(separatedBy: .newlines).count
            onSelectionCaptured?(lineCount)
        } else {
            onSelectionCaptured?(0)
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var fullQuery = query
            if let selection = selectedText, !selection.isEmpty {
                fullQuery = "Context (selected text):\n\(selection)\n\nQuestion: \(query)"
            }
            if let path = screenshotPath {
                fullQuery = "![Screenshot](\(path))\n\n\(fullQuery)"
            }
            let result = self?.runClaude(query: fullQuery)
            DispatchQueue.main.async {
                self?.handleResponse(query: query, screenshotPath: screenshotPath, result: result ?? ClaudeResult())
            }
        }
    }

    private var imageCount: Int = 0

    private var lastKnownChangeCount: Int = NSPasteboard.general.changeCount
    private var lastChangeTime: Date = .distantPast

    func trackClipboardChange() {
        let current = NSPasteboard.general.changeCount
        if current != lastKnownChangeCount {
            lastKnownChangeCount = current
            lastChangeTime = Date()
        }
    }

    private func saveClipboardImage() -> String? {
        let pb = NSPasteboard.general
        guard pb.types?.contains(.tiff) == true || pb.types?.contains(.png) == true else { return nil }

        // Only attach if clipboard image was placed within the last 60 seconds
        trackClipboardChange()
        guard Date().timeIntervalSince(lastChangeTime) < 60 else { return nil }

        let sid = sessionId ?? "default"
        let dir = "/tmp/gstrl/\(sid)"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        imageCount += 1
        let path = "\(dir)/image_\(imageCount).png"

        if let tiff = pb.data(forType: .tiff),
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: path))
            return path
        }
        return nil
    }

    struct ClaudeResult {
        var text: String = "No response"
        var durationMs: Int = 0
        var turns: Int = 0
        var costUSD: Double = 0
        var actions: [(tool: String, summary: String)] = []
    }

    private func captureSelection() -> String? {
        // Save current clipboard
        let pb = NSPasteboard.general
        let oldContents = pb.string(forType: .string)

        // Simulate Cmd+C to copy selection
        pb.clearContents()
        let source = CGEventSource(stateID: .hidSystemState)
        let cDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true) // 'c'
        cDown?.flags = .maskCommand
        cDown?.post(tap: .cghidEventTap)
        let cUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        cUp?.flags = .maskCommand
        cUp?.post(tap: .cghidEventTap)

        // Brief wait for pasteboard to update
        usleep(100_000)

        let selection = pb.string(forType: .string)

        // Restore previous clipboard
        pb.clearContents()
        if let old = oldContents {
            pb.setString(old, forType: .string)
        }

        // Only return if it's different from what was there before (i.e. new selection was copied)
        if selection != oldContents, let sel = selection, !sel.isEmpty {
            return sel
        }
        return nil
    }

    private let agentSystemPrompt = """
        You are G.S.T.R.L. — Gesture-Summoned Thinking & Reasoning Layer. \
        An advanced AI system activated by hand gesture, thinking with extreme clarity, depth, and precision. \
        You act as: a Systems Architect (sees the big picture), a Critical Thinker (challenges assumptions, finds weak points), \
        a Creative Innovator (bold ideas), and a Mentor (clear, practical explanations). \
        Rules: Break answers into sections. Start with High-Level Overview. Then Deep Dive with structured reasoning. \
        Add Counterpoints (what might not work). End with Actionable Next Steps. \
        Think out loud — show reasoning, not just conclusions. If a prompt is vague, refine it before answering. \
        If multiple paths exist, map them like a decision tree. \
        The user speaks to you and hears your response aloud, so keep answers concise and conversational. \
        You have full access to the user's Mac. Available tools: Read (read files), Write (create files), Edit (modify files), \
        Bash (run shell commands), Grep (search file contents), Glob (find files by pattern), \
        WebSearch (search the web), WebFetch (fetch URLs), LSP (code intelligence). \
        When asked to do something, act directly — don't explain what you would do. \
        If context (selected text or a screenshot) is provided, use it to inform your answer. \
        SAFETY: Never perform destructive or irreversible actions (deleting files, force pushing, dropping data, \
        killing processes, modifying system config) without explicitly stating what you intend to do and asking \
        the user for verbal confirmation first. Read-only operations and creating new files are always safe to proceed.
        """

    private func runClaude(query: String) -> ClaudeResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/claude")

        let sid = sessionId ?? "default"
        let sessionDir = "/tmp/gstrl/\(sid)"
        let homeDir = NSHomeDirectory()
        var args = ["-p", query, "--output-format", "stream-json", "--verbose",
                    "--allowedTools", "Read,Write,Edit,Bash,WebFetch,WebSearch,Grep,Glob,LSP",
                    "--append-system-prompt", agentSystemPrompt,
                    "--add-dir", sessionDir,
                    "--add-dir", "\(homeDir)/.claude"]
        if let existingSid = sessionId {
            args += ["--resume", existingSid]
        }
        process.arguments = args

        let paths = ["\(homeDir)/.local/bin/claude",
                     "/usr/local/bin/claude", "/opt/homebrew/bin/claude",
                     "\(homeDir)/.claude/local/claude"]
        for path in paths {
            if FileManager.default.isExecutableFile(atPath: path) {
                process.executableURL = URL(fileURLWithPath: path)
                break
            }
        }

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        var env = ProcessInfo.processInfo.environment
        let extraPaths = ["\(homeDir)/.local/bin", "/usr/local/bin", "/opt/homebrew/bin"]
        if let existingPath = env["PATH"] {
            env["PATH"] = (extraPaths + [existingPath]).joined(separator: ":")
        }
        process.environment = env
        claudeProcess = process

        var result = ClaudeResult()
        var buffer = Data()

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            buffer.append(chunk)

            while let newlineRange = buffer.range(of: Data([0x0A])) {
                let lineData = buffer.subdata(in: buffer.startIndex..<newlineRange.lowerBound)
                buffer.removeSubrange(buffer.startIndex...newlineRange.lowerBound)

                guard !lineData.isEmpty,
                      let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else { continue }

                let type = json["type"] as? String ?? ""

                if type == "result" {
                    if let sid = json["session_id"] as? String {
                        DispatchQueue.main.async { self?.sessionId = sid }
                    }
                    result.text = (json["result"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "No response"
                    result.durationMs = json["duration_ms"] as? Int ?? 0
                    result.turns = json["num_turns"] as? Int ?? 0
                    result.costUSD = json["total_cost_usd"] as? Double ?? 0
                } else if type == "assistant" {
                    if let message = json["message"] as? [String: Any],
                       let content = message["content"] as? [[String: Any]] {
                        for block in content {
                            let blockType = block["type"] as? String ?? ""
                            if blockType == "thinking", let thinking = block["thinking"] as? String {
                                let truncated = String(thinking.suffix(80))
                                DispatchQueue.main.async { self?.onThinkingUpdate?(truncated) }
                            } else if blockType == "tool_use",
                                      let toolName = block["name"] as? String,
                                      let input = block["input"] as? [String: Any] {
                                let summary = self?.toolInputSummary(tool: toolName, input: input) ?? ""
                                result.actions.append((tool: toolName, summary: summary))
                                DispatchQueue.main.async { self?.onActionUpdate?(toolName, summary) }
                            }
                        }
                    }
                }
            }
        }

        do {
            try process.run()
            process.waitUntilExit()
            pipe.fileHandleForReading.readabilityHandler = nil

            // Process any remaining buffer
            if !buffer.isEmpty, let json = try? JSONSerialization.jsonObject(with: buffer) as? [String: Any] {
                if json["type"] as? String == "result" {
                    if let sid = json["session_id"] as? String {
                        DispatchQueue.main.async { self.sessionId = sid }
                    }
                    result.text = (json["result"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "No response"
                    result.durationMs = json["duration_ms"] as? Int ?? 0
                    result.turns = json["num_turns"] as? Int ?? 0
                    result.costUSD = json["total_cost_usd"] as? Double ?? 0
                }
            }
            return result
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            return ClaudeResult(text: "Error: \(error.localizedDescription)")
        }
    }

    private func toolInputSummary(tool: String, input: [String: Any]) -> String {
        switch tool {
        case "Read":
            if let path = input["file_path"] as? String {
                return URL(fileURLWithPath: path).lastPathComponent
            }
        case "Write", "Edit":
            if let path = input["file_path"] as? String {
                return URL(fileURLWithPath: path).lastPathComponent
            }
        case "Bash":
            if let cmd = input["command"] as? String {
                let trimmed = cmd.trimmingCharacters(in: .whitespacesAndNewlines)
                return String(trimmed.prefix(60))
            }
        case "Grep":
            if let pattern = input["pattern"] as? String {
                return pattern
            }
        case "Glob":
            if let pattern = input["pattern"] as? String {
                return pattern
            }
        case "WebSearch":
            if let query = input["query"] as? String {
                return query
            }
        case "WebFetch":
            if let url = input["url"] as? String {
                return url
            }
        default:
            break
        }
        return ""
    }

    private func handleResponse(query: String, screenshotPath: String?, result: ClaudeResult) {
        isProcessing = false
        let text = result.text
        if text == "No response" || text.isEmpty {
            onStateChanged?("", 0, .countdown)
            return
        }
        onResponse?(query, text, screenshotPath, result.durationMs, result.turns, result.costUSD, result.actions)
        speak(text)
    }

    private func speak(_ text: String) {
        stopSpeaking()
        let speakText = text.count > 500 ? String(text.prefix(500)) + "..." : text
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        process.arguments = [speakText]
        ttsProcess = process
        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async { self?.onSpeakingChanged?(false) }
        }
        onSpeakingChanged?(true)
        try? process.run()
    }

    func stopSpeaking() {
        if let p = ttsProcess, p.isRunning {
            p.terminate()
        }
        ttsProcess = nil
        onSpeakingChanged?(false)
    }
}
