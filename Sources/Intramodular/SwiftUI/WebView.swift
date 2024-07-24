//
// Copyright (c) Vatsal Manot
//

#if os(iOS) || os(macOS) || os(visionOS)

import Swift
import SwiftUI
internal import SwiftUIX
import WebKit

public struct WebView: View {
    private let configuration: _BKWebViewRepresentable.Configuration
    
    @State private var state = _WebViewState()
    
    public var body: some View {
        _BKWebViewRepresentable(configuration: configuration, state: $state)
    }
}

extension WebView {
    public init(underlyingView: _BKWebView) {
        self.configuration = .init(underlyingView: underlyingView)
    }
    
    public init(
        url: URL,
        delegate: WebViewDelegate? = nil
    ) {
        self.configuration = .init(url: url, delegate: delegate)
    }
    
    public init(
        url: String,
        delegate: WebViewDelegate? = nil
    ) {
        self.init(url: URL(string: url)!, delegate: delegate)
    }
}

#endif
