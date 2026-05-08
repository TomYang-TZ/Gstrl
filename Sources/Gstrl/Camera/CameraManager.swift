import AVFoundation
import Vision

final class CameraManager: NSObject, @unchecked Sendable {
    private let captureSession = AVCaptureSession()
    private let processingQueue = DispatchQueue(label: "com.gstrl.camera", qos: .userInteractive)
    private var isProcessing = false

    var onFrame: ((_ pixelBuffer: CVPixelBuffer) -> Void)?

    func start() {
        processingQueue.async { [weak self] in
            guard let self else { return }
            if !self.captureSession.isRunning {
                self.configureSession()
                self.captureSession.startRunning()
            }
        }
    }

    func stop() {
        processingQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }

    private func configureSession() {
        guard captureSession.inputs.isEmpty else { return }

        captureSession.sessionPreset = .hd1280x720

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: processingQueue)

        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
        }

        // Target 60fps via connection (device-level setting crashes on DAL devices)
        if let connection = output.connection(with: .video) {
            if connection.isVideoMinFrameDurationSupported {
                connection.videoMinFrameDuration = CMTime(value: 1, timescale: 60)
            }
            if connection.isVideoMaxFrameDurationSupported {
                connection.videoMaxFrameDuration = CMTime(value: 1, timescale: 60)
            }
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !isProcessing else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        isProcessing = true
        onFrame?(pixelBuffer)
        isProcessing = false
    }
}
