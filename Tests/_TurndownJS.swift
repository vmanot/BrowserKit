//
// Copyright (c) Vatsal Manot
//

import FoundationX
import BrowserKit
import XCTest

final class _TurndownJSTests: XCTestCase {
    func testTurndownJS() async throws {
        let turndown = await _TurndownJS()
        
        let urlRequest = URLRequest(url: URL(string: "https://en.wikipedia.org/wiki/Web_scraping")!)
        let htmlString = try await URLSession.shared.data(for: urlRequest).0.toString()
      
        let markdown = try await turndown.convert(htmlString: htmlString)
        
        print(markdown)
    }
}
