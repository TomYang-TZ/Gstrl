import Vision
import CoreImage
import Foundation

final class GazeTracker {
    private let mapper: PolynomialMapper
    private let context = CIContext()

    init(mapper: PolynomialMapper) {
        self.mapper = mapper
    }

    struct GazeResult {
        let rawGazeVector: CGPoint
        let screenPoint: CGPoint
    }

    func processFrame(_ pixelBuffer: CVPixelBuffer, faceObservation: VNFaceObservation) -> GazeResult? {
        guard let faceLandmarks = faceObservation.landmarks,
              let leftEye = faceLandmarks.leftEye,
              let rightEye = faceLandmarks.rightEye else { return nil }

        let imageWidth = CVPixelBufferGetWidth(pixelBuffer)
        let imageHeight = CVPixelBufferGetHeight(pixelBuffer)
        let faceBBox = faceObservation.boundingBox

        let leftPupil = estimatePupilPosition(
            eyeLandmark: leftEye,
            faceBoundingBox: faceBBox,
            pixelBuffer: pixelBuffer,
            imageWidth: imageWidth,
            imageHeight: imageHeight
        )

        let rightPupil = estimatePupilPosition(
            eyeLandmark: rightEye,
            faceBoundingBox: faceBBox,
            pixelBuffer: pixelBuffer,
            imageWidth: imageWidth,
            imageHeight: imageHeight
        )

        guard let lp = leftPupil, let rp = rightPupil else {
            return (leftPupil ?? rightPupil).map { pupil in
                let screenPoint = mapper.isCalibrated ? mapper.map(pupil) : .zero
                return GazeResult(rawGazeVector: pupil, screenPoint: screenPoint)
            }
        }

        let avgPupil = CGPoint(x: (lp.x + rp.x) / 2, y: (lp.y + rp.y) / 2)
        let screenPoint = mapper.isCalibrated ? mapper.map(avgPupil) : .zero
        return GazeResult(rawGazeVector: avgPupil, screenPoint: screenPoint)
    }

    private func estimatePupilPosition(
        eyeLandmark: VNFaceLandmarkRegion2D,
        faceBoundingBox: CGRect,
        pixelBuffer: CVPixelBuffer,
        imageWidth: Int,
        imageHeight: Int
    ) -> CGPoint? {
        let points = eyeLandmark.normalizedPoints

        let xs = points.map(\.x)
        let ys = points.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else { return nil }

        let facePixelX = faceBoundingBox.origin.x * CGFloat(imageWidth)
        let facePixelY = faceBoundingBox.origin.y * CGFloat(imageHeight)
        let facePixelW = faceBoundingBox.width * CGFloat(imageWidth)
        let facePixelH = faceBoundingBox.height * CGFloat(imageHeight)

        let eyeRect = CGRect(
            x: facePixelX + CGFloat(minX) * facePixelW,
            y: facePixelY + CGFloat(minY) * facePixelH,
            width: CGFloat(maxX - minX) * facePixelW,
            height: CGFloat(maxY - minY) * facePixelH
        )

        let expandedRect = eyeRect.insetBy(dx: -eyeRect.width * 0.1, dy: -eyeRect.height * 0.2)
        guard expandedRect.width > 0, expandedRect.height > 0 else { return nil }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let cropped = ciImage.cropped(to: expandedRect)

        guard let cgImage = context.createCGImage(cropped, from: cropped.extent) else { return nil }

        return findDarkestCentroid(in: cgImage)
    }

    private func findDarkestCentroid(in image: CGImage) -> CGPoint {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return CGPoint(x: 0.5, y: 0.5) }

        guard let data = image.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else {
            return CGPoint(x: 0.5, y: 0.5)
        }

        let bytesPerPixel = image.bitsPerPixel / 8
        let bytesPerRow = image.bytesPerRow
        let threshold: UInt8 = 60

        let alphaInfo = image.alphaInfo
        let byteOrder = image.bitmapInfo.intersection(.byteOrderMask)
        let isBGRA = byteOrder == .byteOrder32Little || alphaInfo == .premultipliedFirst

        var sumX: Double = 0
        var sumY: Double = 0
        var count: Double = 0

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let r: UInt8
                let g: UInt8
                let b: UInt8
                if isBGRA {
                    b = bytes[offset]
                    g = bytes[offset + 1]
                    r = bytes[offset + 2]
                } else {
                    r = bytes[offset]
                    g = bytes[offset + 1]
                    b = bytes[offset + 2]
                }
                let gray = (UInt16(r) + UInt16(g) + UInt16(b)) / 3

                if gray < UInt16(threshold) {
                    sumX += Double(x)
                    sumY += Double(y)
                    count += 1
                }
            }
        }

        guard count > 0 else { return CGPoint(x: 0.5, y: 0.5) }

        return CGPoint(
            x: sumX / count / Double(width),
            y: sumY / count / Double(height)
        )
    }
}
