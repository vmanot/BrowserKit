//
// Copyright (c) Vatsal Manot
//

import Diagnostics
import Swallow
import WebKit

@MainActor
public final class _ShowdownJS {
    private static let javascript = try! String(contentsOf: Bundle.module.url(forResource: "showdown.min", withExtension: "js")!)
    
    private let webView = _BKWebView()
    
    public init() {
        
    }
    
    public func convert(_ html: String) async throws -> String {
        guard !html.isEmpty else {
            return html
        }
        
        try await webView.load()
        
        let html = encloseInHTMLTags(html)
        
        let base64HtmlString = try html.data(using: .utf8, allowLossyConversion: false)
            .unwrap()
            .base64EncodedString()
        
        try await webView.loadScript(Self.javascript)
        
        let script = """
        var converter = new showdown.Converter();
        var html = atob('\(base64HtmlString)');
        return converter.makeMarkdown(html);
        """
        
        let result = try cast(try await webView.callAsyncJavaScript(script, contentWorld: .page), to: String.self)
        
        return result
    }
    
    func encloseInHTMLTags(_ html: String) -> String {
        if let _ = html.range(of: "<html[^>]*>.*</html>", options: .regularExpression, range: nil, locale: nil) {
            return html
        } else {
            return "<html>\(html)</html>"
        }
    }
}
