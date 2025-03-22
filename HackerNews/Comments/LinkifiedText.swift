import SwiftUI

struct LinkifiedText: View {
    let text: String
    @State private var selectedURL: URL? = nil
    @State private var showWebView = false
    
    var body: some View {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) ?? []
        
        Text(text)
            .tint(.accentColor)
            .environment(\.openURL, OpenURLAction { url in
                selectedURL = url
                showWebView = true
                return .handled
            })
            .sheet(isPresented: $showWebView) {
                if let url = selectedURL {
                    NavigationView {
                        WebView(url: url)
                    }
                }
            }
    }
}

struct LinkifiedText_Previews: PreviewProvider {
    static var previews: some View {
        LinkifiedText(text: "Check out this link: https://example.com")
    }
}
