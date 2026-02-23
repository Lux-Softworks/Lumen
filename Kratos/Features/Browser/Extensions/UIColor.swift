import UIKit

extension UIColor {
    static func fromAnyString(_ str: String) -> UIColor? {
        let clean = str.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if clean.hasPrefix("#") {
            let hex = clean.replacingOccurrences(of: "#", with: "")
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 1

            let scanner = Scanner(string: hex)
            var hexNumber: UInt64 = 0

            if scanner.scanHexInt64(&hexNumber) {
                if hex.count == 6 {
                    r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
                    g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
                    b = CGFloat(hexNumber & 0x0000ff) / 255
                    return UIColor(red: r, green: g, blue: b, alpha: a)
                } else if hex.count == 8 {
                    r = CGFloat((hexNumber & 0xff00_0000) >> 24) / 255
                    g = CGFloat((hexNumber & 0x00ff_0000) >> 16) / 255
                    b = CGFloat((hexNumber & 0x0000_ff00) >> 8) / 255
                    a = CGFloat(hexNumber & 0x0000_00ff) / 255
                    return UIColor(red: r, green: g, blue: b, alpha: a)
                }
            }
        } else if clean.hasPrefix("rgb") {
            let components = clean.replacingOccurrences(of: "rgba(", with: "")
                .replacingOccurrences(of: "rgb(", with: "")
                .replacingOccurrences(of: ")", with: "")
                .split(separator: ",")
                .compactMap {
                    Double($0.trimmingCharacters(in: .whitespaces))
                }

            if components.count >= 3 {
                let r = CGFloat(components[0]) / 255.0
                let g = CGFloat(components[1]) / 255.0
                let b = CGFloat(components[2]) / 255.0
                let a = components.count >= 4 ? CGFloat(components[3]) : 1.0
                return UIColor(red: r, green: g, blue: b, alpha: a)
            }
        } else {
            switch clean {
            case "white": return .white
            case "black": return .black
            case "gray": return .gray
            case "red": return .red
            case "blue": return .blue
            case "green": return .green
            case "yellow": return .yellow
            case "orange": return .orange
            case "purple": return .purple
            case "brown": return .brown
            case "cyan": return .cyan
            case "magenta": return .magenta
            case "transparent", "clear": return .clear
            default: return nil
            }
        }

        return nil
    }
}
