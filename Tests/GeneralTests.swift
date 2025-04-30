//
//  File.swift
//  BrowserKit
//
//  Created by Purav Manot on 30/04/25.
//

import Foundation
import Testing
@testable import BrowserKit

struct GeneralTests {
    @Test("Repeated load")
    func testRepeatedLoads() async throws {
        let webView = await _BKWebView()
        let url = URL(string: "https://google.com")!
        
        let success = await withDiscardingTaskGroup(returning: Bool.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    let navigation = try? await webView.load(url)
                    try? await Task.sleep(for: .milliseconds(Int.random(in: 0..<100)))
                    print(navigation?.urlResponse)
                }
            }
            
            return true
        }
        
        #expect(success)
    }
}


