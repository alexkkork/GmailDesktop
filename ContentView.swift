import SwiftUI
import WebKit

struct ContentView: View {
    var body: some View {
        GmailWebView(url: URL(string: "https://mail.google.com/")!)
            .ignoresSafeArea()
    }
}
