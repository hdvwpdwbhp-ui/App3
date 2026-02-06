import SwiftUI

struct ContentView: View {
    var body: some View {
        LocalHTMLWebView(fileName: "index", fileExtension: "html")
            .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}
