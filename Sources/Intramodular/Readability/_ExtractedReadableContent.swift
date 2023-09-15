//
// Copyright (c) Vatsal Manot
//

import Diagnostics
import Foundation
import Swallow

public struct _ExtractedReadableContent: Equatable {
    // See https://github.com/postlight/mercury-parser#usage
    public var htmlString: String
    public var author: String?
    public var title: String?
    public var excerpt: String?
}
