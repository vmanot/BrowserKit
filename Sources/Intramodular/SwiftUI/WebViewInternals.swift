//
// Copyright (c) Vatsal Manot
//

#if os(iOS) || os(macOS)

import Swift
import SwiftUIX
import WebKit

struct _WebViewConfiguration {
    var underlyingView: _BKWebView?
    var url: URL?
    var delegate: WebViewDelegate?
}

public protocol WebViewDelegate {
    func cookiesUpdated(_ cookies: [HTTPCookie])
}

public struct _WebViewState {
    var isLoading: Bool?
}

extension WebView {
    struct _BKWebViewRepresentable: AppKitOrUIKitViewRepresentable {
        public typealias AppKitOrUIKitViewType = _BKWebView
        
        typealias Configuration = _WebViewConfiguration
        
        let configuration: Configuration
        
        @Binding var state: _WebViewState
        
        func makeAppKitOrUIKitView(context: Context) -> AppKitOrUIKitViewType {
            if let underlyingView = configuration.underlyingView {
                return underlyingView
            }
            
            let view = _BKWebView()
            
            if let url = configuration.url {
                view.load(url)
            }
            
            return view
        }
        
        func updateAppKitOrUIKitView(_ view: AppKitOrUIKitViewType, context: Context) {
            func updateWebViewProxy() {
                if let _webViewProxy = context.environment._webViewProxy {
                    if _webViewProxy.wrappedValue.base !== view {
                        DispatchQueue.main.async {
                            _webViewProxy.wrappedValue.base = view
                        }
                    }
                }
            }
            
            view.coordinator = context.coordinator
            
            context.coordinator.configuration = configuration
            context.coordinator._updateStateBinding($state)
            
            updateWebViewProxy()
        }
        
        static func dismantleAppKitOrUIKitView(_ view: AppKitOrUIKitViewType, coordinator: Coordinator) {
            
        }
        
        func makeCoordinator() -> Coordinator {
            Coordinator(configuration: configuration, state: $state)
        }
    }
}

extension WebView._BKWebViewRepresentable {
    class Coordinator: NSObject, ObservableObject, WKNavigationDelegate {
        var configuration: _WebViewConfiguration
        
        @Binding var state: _WebViewState
        
        var cookies: [HTTPCookie]? {
            didSet {
                if let cookies = cookies {
                    configuration.delegate?.cookiesUpdated(cookies)
                }
            }
        }
        
        init(configuration: _WebViewConfiguration, state: Binding<_WebViewState>) {
            self.configuration = configuration
            self._state = state
        }
        
        fileprivate func _updateStateBinding(_ state: Binding<_WebViewState>) {
            self._state = state
        }
    }
}

#endif
