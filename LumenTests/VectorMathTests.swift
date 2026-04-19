import Testing
@testable import Lumen

struct VectorMathTests {
    @Test func identicalVectorsYieldOne() {
        let v: [Double] = [1, 2, 3, 4]
        #expect(abs(VectorMath.cosineSimilarity(v, v) - 1.0) < 1e-9)
    }

    @Test func orthogonalVectorsYieldZero() {
        let a: [Double] = [1, 0]
        let b: [Double] = [0, 1]
        #expect(abs(VectorMath.cosineSimilarity(a, b)) < 1e-9)
    }

    @Test func oppositeVectorsYieldNegativeOne() {
        let a: [Double] = [1, 2, 3]
        let b: [Double] = [-1, -2, -3]
        #expect(abs(VectorMath.cosineSimilarity(a, b) + 1.0) < 1e-9)
    }

    @Test func mismatchedLengthsYieldZero() {
        #expect(VectorMath.cosineSimilarity([1, 2], [1, 2, 3]) == 0)
    }

    @Test func emptyVectorsYieldZero() {
        #expect(VectorMath.cosineSimilarity([], []) == 0)
    }
}
