//
// Copyright (c) Vatsal Manot
//

import Swallow

extension _BKWebView {
    public func currentHTML() async throws -> String {
        try await load()
        
        let result = try await evaluateJavaScript("document.documentElement.outerHTML.toString()")
        
        return try cast(result, to: String.self)
    }
}
