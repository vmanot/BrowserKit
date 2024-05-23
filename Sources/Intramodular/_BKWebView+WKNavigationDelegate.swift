//
// Copyright (c) Vatsal Manot
//

internal import Merge
import Swallow
@preconcurrency import WebKit

extension _BKWebView: WKNavigationDelegate {
    public func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        .allow
    }
    
    public func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        preferences: WKWebpagePreferences
    ) async -> (WKNavigationActionPolicy, WKWebpagePreferences) {
        let policy = await self.webView(webView, decidePolicyFor: navigationAction)
        
        return (policy, preferences)
    }
    
    public func webView(
        _ webView: WKWebView,
        didStartProvisionalNavigation navigation: WKNavigation?
    ) {
        Task.detached {
            try await self.task(for: navigation)
        }
    }
    
    public func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse
    ) async -> WKNavigationResponsePolicy {
        await self._navigationState.setLastResponse(navigationResponse)
        
        guard
            let response = navigationResponse.response as? HTTPURLResponse,
            let allHeaderFields = response.allHeaderFields as? [String: String],
            let url = response.url
        else {
            return .allow
        }
        
        Task {
            await updateCookies(HTTPCookie.cookies(withResponseHeaderFields: allHeaderFields, for: url))
        }
        
        return .allow
    }
    
    public func webView(
        _ webView: WKWebView,
        didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation?
    ) {
        
    }
    
    public func webView(
        _ webView: WKWebView,
        didCommit navigation: WKNavigation?
    ) {
        Task {
            await syncCookiesToSharedHTTPCookieStorage(webView: webView)
        }
    }
    
    public func webView(
        _ webView: WKWebView,
        didFinish navigation: WKNavigation?
    ) {
        if url?.absoluteString != nil {
            coordinator?.state.isLoading = false
        }
        
        Task.detached {
            await self._navigationState.resolve(navigation, with: .success(()))
        }
    }
    
    public func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation?,
        withError error: Error
    ) {
        Task.detached {
            await self._navigationState.resolve(navigation, with: .error(error))
        }
    }
    
    public func webView(
        _ webView: WKWebView,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let challenge = _UncheckedSendable(challenge)
        
        Task.detached {
            let challenge = challenge.wrappedValue
            var disposition: URLSession.AuthChallengeDisposition = .performDefaultHandling
            var credential: URLCredential?
            
            if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
                if let serverTrust = challenge.protectionSpace.serverTrust {
                    credential = URLCredential(trust: serverTrust)
                    disposition = .useCredential
                }
            } else {
                disposition = .cancelAuthenticationChallenge
            }
            
            completionHandler(disposition, credential)
        }
    }
    
    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        
    }
}
