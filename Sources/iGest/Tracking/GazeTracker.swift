import Foundation

final class GazeTracker {
    let mapper: PolynomialMapper
    private var socketFD: Int32 = -1
    private var buffer = ""
    private(set) var latestGaze: CGPoint = CGPoint(x: 0.5, y: 0.5)
    private(set) var latestHandState: TrackingState = .inactive
    private var isConnected = false
    private let queue = DispatchQueue(label: "com.igest.gaze-socket")
    private let socketPath = "/Users/tomyang/iGest/.igest_gaze.sock"

    struct GazeResult {
        let rawGazeVector: CGPoint
        let screenPoint: CGPoint
    }

    init(mapper: PolynomialMapper) {
        self.mapper = mapper
        queue.async { [weak self] in
            self?.connect()
        }
    }

    func getLatestGaze() -> GazeResult? {
        let gaze = latestGaze
        let screenPoint = mapper.isCalibrated ? mapper.map(gaze) : .zero
        return GazeResult(rawGazeVector: gaze, screenPoint: screenPoint)
    }

    private func connect() {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            retryConnect()
            return
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        socketPath.withCString { cstr in
            withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: 104) { dest in
                    _ = strcpy(dest, cstr)
                }
            }
        }

        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                Foundation.connect(fd, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard result == 0 else {
            close(fd)
            retryConnect()
            return
        }

        NSLog("iGest: Connected to vision server")
        socketFD = fd
        isConnected = true
        readLoop()
    }

    private func readLoop() {
        let fd = socketFD
        var buf = [UInt8](repeating: 0, count: 4096)

        queue.async { [weak self] in
            while self?.isConnected == true {
                let n = read(fd, &buf, buf.count)
                if n <= 0 {
                    self?.isConnected = false
                    NSLog("iGest: Socket disconnected")
                    self?.retryConnect()
                    return
                }
                if let str = String(bytes: buf[0..<n], encoding: .utf8) {
                    self?.processData(str)
                }
            }
        }
    }

    private func processData(_ str: String) {
        buffer += str
        while let newlineIndex = buffer.firstIndex(of: "\n") {
            let line = String(buffer[buffer.startIndex..<newlineIndex])
            buffer = String(buffer[buffer.index(after: newlineIndex)...])
            parseLine(line)
        }
    }

    private func parseLine(_ line: String) {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let gazeArr = json["gaze"] as? [Double],
              let handStr = json["hand"] as? String,
              gazeArr.count == 2 else { return }

        latestGaze = CGPoint(x: gazeArr[0], y: gazeArr[1])

        switch handStr {
        case "tracking": latestHandState = .tracking
        case "pinching": latestHandState = .pinching
        default: latestHandState = .inactive
        }
    }

    private func retryConnect() {
        queue.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.connect()
        }
    }
}
