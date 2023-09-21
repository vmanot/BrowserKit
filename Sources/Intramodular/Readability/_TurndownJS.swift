//
// Copyright (c) Vatsal Manot
//

import Diagnostics
import Swallow
import WebKit

/// BrowserKit's convenience wrapper over `turndown`.
///
/// turndown.js is a JavaScript library that converts HTML into Markdown.
///
/// References:
/// - https://github.com/mixmark-io/turndown
@MainActor
public final class _TurndownJS {
    private let js = try! String(contentsOf: Bundle.module.url(forResource: "turndown", withExtension: "js")!)
    
    private let webView = _BKWebView()
    
    public init() {
        
    }
    
    /// Converts the given HTML into Markdown.
    public func convert(
        htmlString: String
    ) async throws -> String {
        guard !htmlString.isEmpty else {
            return htmlString
        }
        
        let base64HtmlString = try htmlString.data(using: .utf8, allowLossyConversion: false)
            .unwrap()
            .base64EncodedString()
        
        try await webView.loadScript(js)
        
        let script = """
        var turndownService = new TurndownService();
        var html = decodeURIComponent(atob('\(base64HtmlString)').split('').map(c => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2)).join(''));
        return turndownService.turndown(html);
        """
        
        let result = try await webView.callAsyncJavaScript(script, contentWorld: .page)
        
        return try cast(result, to: String.self)
    }
}
