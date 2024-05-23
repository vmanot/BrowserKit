//
// Copyright (c) Vatsal Manot
//

import Foundation
internal import Merge
import Swallow
import SwiftSoup
import WebKit

public struct _ReadableSiteMetadata: Equatable, Codable {    
    public var url: URL
    public var title: String?
    public var description: String?
    public var heroImage: URL?
    public var favicon: URL?

    public init(
        htmlString: String,
        baseURL: URL
    ) throws {
        let document = try SwiftSoup.parse(htmlString)
        
        self.url = baseURL
        self.title = try? document.ogTitle ?? document.title
        self.heroImage = document.ogImage(baseURL: baseURL)
        self.description = document.metaDescription.nilIfEmpty()
        self.favicon = try? document.favicon(baseURL: baseURL) ?? baseURL.inferredFaviconURL
    }
}

// MARK: - Auxiliary

extension SwiftSoup.Document {
    fileprivate var title: String? {
        get throws {
            try firstChild(tag: "head")?.firstChild(tag: "title")?.val()
        }
    }
    
    fileprivate var metaDescription: String? {
        firstAttribute(selector: "meta[name='description']", attribute: "content")
    }
    
    fileprivate var ogTitle: String? {
        firstAttribute(selector: "meta[property='og:title']", attribute: "content")
    }
    
    fileprivate func ogImage(baseURL: URL) -> URL? {
        if let link = firstAttribute(selector: "meta[property='og:image']", attribute: "content") {
            return URL(string: link, relativeTo: baseURL)
        }
        
        return nil
    }
    
    fileprivate func favicon(baseURL: URL) throws -> URL? {
        for item in try select("link") {
            if let rel = try? item.attr("rel"),
               (rel == "icon" || rel == "shortcut icon"),
               let val = try? item.attr("href"),
               let resolved = URL(string: val, relativeTo: baseURL)
            {
                return resolved
            }
        }
        
        return nil
    }
}

// MARK: - Auxiliary

extension URL {
    fileprivate var inferredFaviconURL: URL {
        return URL(string: "/favicon.ico", relativeTo: self)!
    }
}
