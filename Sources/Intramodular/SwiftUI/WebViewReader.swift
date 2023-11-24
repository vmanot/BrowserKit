//
// Copyright (c) Vatsal Manot
//

#if os(iOS) || os(macOS) || os(visionOS)

import Swift
import SwiftUIX
import WebKit

/// A view whose child is defined as a function of a `WebViewProxy` targeting the collection views within the child.
public struct WebViewReader<Content: View>: View {
    @Environment(\._webViewProxy) var _environment_webViewProxy
    
    public let content: (WebViewProxy) -> Content
    
    @State private var _webViewProxy = WebViewProxy()
    
    public init(
        @ViewBuilder content: @escaping (WebViewProxy) -> Content
    ) {
        self.content = content
    }
    
    public var body: some View {
        content(_environment_webViewProxy?.wrappedValue ?? _webViewProxy)
            .environment(\._webViewProxy, $_webViewProxy)
    }
}

public struct WebViewProxy: Hashable {
    weak var base: _BKWebView?
    
    public var webView: _BKWebView? {
        base
    }
}

// MARK: - Auxiliary

extension EnvironmentValues {
    struct WebViewProxyKey: EnvironmentKey {
        static let defaultValue: Binding<WebViewProxy>? = nil
    }
    
    var _webViewProxy: Binding<WebViewProxy>? {
        get {
            self[WebViewProxyKey.self]
        } set {
            self[WebViewProxyKey.self] = newValue
        }
    }
}

#endif
