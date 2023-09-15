//
// Copyright (c) Vatsal Manot
//

import Diagnostics
import Foundation
import Swallow

public final class Readability: Logging {
    public enum Engine: Equatable {
        case mercury
        case readability
    }
    
    public let engine: Engine
    
    public init(engine: Engine) {
        self.engine = engine
    }
    
    public func extract(
        from url: URL
    ) async throws -> Output {
        let (data, response) = try await URLSession.shared.data(from: url)
        
        let html = try String(data: data, encoding: .utf8).unwrap()
        let baseURL = response.url ?? url
        let content = try await extract(from: baseURL, htmlString: html)
        let metadata = try? _ReadableSiteMetadata(htmlString: html, baseURL: baseURL)
        
        return .init(
            metadata: metadata,
            content: content
        )
    }
    
    public func extract(
        from url: URL,
        htmlString: String
    ) async throws -> _ExtractedReadableContent {
        switch engine {
            case .mercury:
                return try await _PostlightParserJS().extract(from: url, htmlString: htmlString)
            case .readability:
                return try await _ReadabilityJS().extract(from: url, htmlString: htmlString)
        }
    }
}

extension Readability {
    public struct Output {
        public var metadata: _ReadableSiteMetadata?
        public var content: _ExtractedReadableContent
        
        public var title: String? {
            content.title?.nilIfEmpty() ?? metadata?.title?.nilIfEmpty()
        }
        
        public var author: String? {
            content.author
        }
        
        public var excerpt: String? {
            content.excerpt ?? metadata?.description
        }
    }
}
