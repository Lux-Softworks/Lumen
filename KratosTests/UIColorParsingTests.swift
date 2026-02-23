import XCTest
import UIKit
@testable import Kratos

final class UIColorParsingTests: XCTestCase {
    private func assertColorsEqual(_ color1: UIColor?, _ color2: UIColor?, file: StaticString = #file, line: UInt = #line) {
        guard let c1 = color1, let c2 = color2 else {
            if color1 == nil && color2 == nil { return }
            XCTFail("One or both colors are nil: \(String(describing: color1)) vs \(String(describing: color2))", file: file, line: line)
            return
        }

        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

        c1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        c2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        let threshold: CGFloat = 0.005
        XCTAssertEqual(r1, r2, accuracy: threshold, "Red component mismatch", file: file, line: line)
        XCTAssertEqual(g1, g2, accuracy: threshold, "Green component mismatch", file: file, line: line)
        XCTAssertEqual(b1, b2, accuracy: threshold, "Blue component mismatch", file: file, line: line)
        XCTAssertEqual(a1, a2, accuracy: threshold, "Alpha component mismatch", file: file, line: line)
    }

    func testParseHex6() {
        assertColorsEqual(UIColor.fromAnyString("#FFFFFF"), .white)
        assertColorsEqual(UIColor.fromAnyString("#000000"), .black)
        assertColorsEqual(UIColor.fromAnyString("#FF0000"), .red)
        assertColorsEqual(UIColor.fromAnyString("#00FF00"), .green)
        assertColorsEqual(UIColor.fromAnyString("#0000FF"), .blue)
    }

    func testParseHex8() {
        assertColorsEqual(UIColor.fromAnyString("#FFFFFF00"), UIColor.white.withAlphaComponent(0))
        assertColorsEqual(UIColor.fromAnyString("#FF000080"), UIColor.red.withAlphaComponent(128.0/255.0))
    }

    func testParseRGB() {
        assertColorsEqual(UIColor.fromAnyString("rgb(255, 255, 255)"), .white)
        assertColorsEqual(UIColor.fromAnyString("rgb(255,0,0)"), .red)
        assertColorsEqual(UIColor.fromAnyString("  rgb( 0 , 255 , 0 )  "), .green)
    }

    func testParseRGBA() {
        assertColorsEqual(UIColor.fromAnyString("rgba(255, 255, 255, 1.0)"), .white)
        assertColorsEqual(UIColor.fromAnyString("rgba(255, 255, 255, 0.5)"), UIColor.white.withAlphaComponent(0.5))
        assertColorsEqual(UIColor.fromAnyString("rgba(0,0,0,0)"), .clear)
    }

    func testParseNamedColors() {
        assertColorsEqual(UIColor.fromAnyString("white"), .white)
        assertColorsEqual(UIColor.fromAnyString("black"), .black)
        assertColorsEqual(UIColor.fromAnyString("red"), .red)
        assertColorsEqual(UIColor.fromAnyString("blue"), .blue)
        assertColorsEqual(UIColor.fromAnyString("transparent"), .clear)
        assertColorsEqual(UIColor.fromAnyString("clear"), .clear)
    }

    func testInvalidInputs() {
        XCTAssertNil(UIColor.fromAnyString(""))
        XCTAssertNil(UIColor.fromAnyString("#123"))
        XCTAssertNil(UIColor.fromAnyString("#GGGGGG"))
        XCTAssertNil(UIColor.fromAnyString("notacolor"))
        XCTAssertNil(UIColor.fromAnyString("rgb(1,2)"))
    }

    func testCaseInsensitivityAndWhitespace() {
        assertColorsEqual(UIColor.fromAnyString("  #ffffff  "), .white)
        assertColorsEqual(UIColor.fromAnyString("WHITE"), .white)
        assertColorsEqual(UIColor.fromAnyString("Rgb(255, 255, 255)"), .white)
    }
}
