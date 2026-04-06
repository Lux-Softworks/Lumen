import Foundation

enum TabViewState: Equatable {
    case fullScreen
    case shrinking
    case shrunk
    case expanding

    var isTransitioning: Bool {
        self == .shrinking || self == .expanding
    }
}
