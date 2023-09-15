//
// Copyright (c) Vatsal Manot
//

#if os(iOS) || os(macOS)

import WebKit

extension WKNavigation {
    public struct Success: Sendable {
        public let urlResponse: URLResponse
    }
}

#endif
