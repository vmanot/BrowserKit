//
// Copyright (c) Vatsal Manot
//

import Diagnostics
import Foundation
import Swallow
import WebKit

@MainActor
public class _ReadabilityJS: Logging {
    private let webView = _BKWebView()
    
    public init() async throws {
        let js = try String(contentsOf: Bundle.module.url(forResource: "readability.bundle.min", withExtension: "js")!)
        
        try await webView.loadScript(js)
    }
    
    public func extract(
        from url: URL,
        htmlString: String
    ) async throws -> _ExtractedReadableContent {
        let script = "return await parse(\(htmlString._encodeAsTopLevelJSON()), \(url.absoluteString._encodeAsTopLevelJSON()))"
        
        let result = try await self.webView
            .callAsyncJavaScript(script, arguments: [:], in: nil, contentWorld: .page)
            .map({ try cast($0, to: [String: Any].self) })
        
        return try self.parse(from: result).unwrap()
    }
    
    private func parse(
        from result: [String: Any]?
    ) throws -> _ExtractedReadableContent? {
        guard let result else {
            return nil
        }
        
        return try _ExtractedReadableContent(
            htmlString: (result["content"] as? String).unwrap(),
            author: result["author"] as? String,
            title: result["title"] as? String,
            excerpt: result["excerpt"] as? String
        )
    }
}
