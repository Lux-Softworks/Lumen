import SwiftUI

struct ContentView: View {
    private let startURL = URL(string: "https://kosukhin.com")!

    var body: some View {
        HardenedWebView(url: startURL)
    }
}

#Preview {
    ContentView()
}
