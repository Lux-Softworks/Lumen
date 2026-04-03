import Foundation
import Accelerate

enum VectorMath {
    static func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var dotProduct: Double = 0
        vDSP_dotprD(a, 1, b, 1, &dotProduct, vDSP_Length(a.count))

        var sumSquaresA: Double = 0
        vDSP_svesqD(a, 1, &sumSquaresA, vDSP_Length(a.count))
        let magA = sqrt(sumSquaresA)

        var sumSquaresB: Double = 0
        vDSP_svesqD(b, 1, &sumSquaresB, vDSP_Length(b.count))
        let magB = sqrt(sumSquaresB)

        guard magA > 0 && magB > 0 else { return 0 }

        return dotProduct / (magA * magB)
    }
}
