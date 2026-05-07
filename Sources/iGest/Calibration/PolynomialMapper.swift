import Foundation
import Accelerate

final class PolynomialMapper {
    private var coefficientsX: [Double]?
    private var coefficientsY: [Double]?

    var isCalibrated: Bool { coefficientsX != nil }

    func calibrate(gazePoints: [CGPoint], screenPoints: [CGPoint]) {
        guard gazePoints.count >= 6 else { return }

        let n = gazePoints.count
        let cols = 6
        // Column-major layout required by LAPACK dgels_
        var matrix = [Double](repeating: 0, count: n * cols)
        var targetX = [Double](repeating: 0, count: n)
        var targetY = [Double](repeating: 0, count: n)

        for i in 0..<n {
            let gx = Double(gazePoints[i].x)
            let gy = Double(gazePoints[i].y)
            matrix[i + 0 * n] = 1
            matrix[i + 1 * n] = gx
            matrix[i + 2 * n] = gy
            matrix[i + 3 * n] = gx * gx
            matrix[i + 4 * n] = gy * gy
            matrix[i + 5 * n] = gx * gy
            targetX[i] = Double(screenPoints[i].x)
            targetY[i] = Double(screenPoints[i].y)
        }

        coefficientsX = solveLeastSquares(matrix: matrix, target: targetX, rows: n, cols: cols)
        coefficientsY = solveLeastSquares(matrix: matrix, target: targetY, rows: n, cols: cols)
    }

    func map(_ gazePoint: CGPoint) -> CGPoint {
        guard let cx = coefficientsX, let cy = coefficientsY else { return .zero }

        let gx = Double(gazePoint.x)
        let gy = Double(gazePoint.y)
        let features = [1.0, gx, gy, gx * gx, gy * gy, gx * gy]

        let screenX = zip(cx, features).reduce(0.0) { $0 + $1.0 * $1.1 }
        let screenY = zip(cy, features).reduce(0.0) { $0 + $1.0 * $1.1 }

        return CGPoint(x: screenX, y: screenY)
    }

    private func solveLeastSquares(matrix: [Double], target: [Double], rows: Int, cols: Int) -> [Double]? {
        var a = matrix
        var b = target
        var m = __CLPK_integer(rows)
        var n = __CLPK_integer(cols)
        var nrhs: __CLPK_integer = 1
        var lda = m
        var ldb = m
        var work = [Double](repeating: 0, count: 1)
        var lwork: __CLPK_integer = -1
        var info: __CLPK_integer = 0

        var trans: CChar = Int8(UInt8(ascii: "N"))
        dgels_(&trans, &m, &n, &nrhs, &a, &lda, &b, &ldb, &work, &lwork, &info)
        lwork = __CLPK_integer(work[0])
        work = [Double](repeating: 0, count: Int(lwork))

        dgels_(&trans, &m, &n, &nrhs, &a, &lda, &b, &ldb, &work, &lwork, &info)

        guard info == 0 else { return nil }
        return Array(b.prefix(cols))
    }

    func save() {
        if let cx = coefficientsX {
            UserDefaults.standard.set(cx, forKey: "igest.calibration.coeffX")
        }
        if let cy = coefficientsY {
            UserDefaults.standard.set(cy, forKey: "igest.calibration.coeffY")
        }
    }

    func load() -> Bool {
        guard let cx = UserDefaults.standard.array(forKey: "igest.calibration.coeffX") as? [Double],
              let cy = UserDefaults.standard.array(forKey: "igest.calibration.coeffY") as? [Double] else {
            return false
        }
        coefficientsX = cx
        coefficientsY = cy
        return true
    }
}
