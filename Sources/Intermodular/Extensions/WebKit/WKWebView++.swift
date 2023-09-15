//
// Copyright (c) Vatsal Manot
//

#if os(iOS) || os(macOS)

import Swift
import WebKit

extension WKWebView {
    /// Loads the web content that the specified URL references and navigates to that content.
    public func load(_ url: URL) {
        load(URLRequest(url: url))
    }
}

#endif
