//
// Copyright (c) Vatsal Manot
//

import Foundation
import Swallow

extension String {
    @_spi(Internal)
    public func _encodeAsTopLevelJSON() -> String {
        let data = try! JSONSerialization.data(withJSONObject: self, options: .fragmentsAllowed)
        
        return String(data: data, encoding: .utf8)!
    }
}

extension String {
    var wrappedInSelfCallingJSFunction: String {
        "(function() { \(self) })()"
    }
}
