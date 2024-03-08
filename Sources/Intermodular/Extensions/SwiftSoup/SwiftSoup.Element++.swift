//
// Copyright (c) Vatsal Manot
//

import Swallow
import SwiftSoup

extension SwiftSoup.Element {
    func firstChild(
        tag: String? = nil,
        id: String? = nil
    ) -> Element? {
        self.children().first {
            if let id {
                guard $0.id() == id else {
                    return false
                }
            }
            
            if let tag {
                guard $0.tag().toString() == tag else {
                    return false
                }
            }
            
            return true
        }
    }
    
    func firstAttribute(
        selector: String,
        attribute: String
    ) -> String? {
        try? select(selector).first(byUnwrapping: { try? $0.attr(attribute) })
    }
}
