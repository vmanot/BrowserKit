//
//  File.swift
//  BrowserKit
//
//  Created by Purav Manot on 29/04/25.
//

import Foundation

extension _BKWebView {
    public struct NetworkMessagePattern: Identifiable {
        enum Payload {
            case custom((NetworkMessage) throws -> Bool)
        }
        
        let identifier: _AutoIncrementingIdentifier<Int> = _AutoIncrementingIdentifier()
        let payload: Payload
        
        public var id: AnyHashable {
            identifier
        }
        
        private init(payload: Payload) {
            self.payload = payload
        }
        
        public init(predicate: @escaping (NetworkMessage) throws -> Bool) {
            self.init(payload: .custom(predicate))
        }
        
        public func matches(_ message: NetworkMessage) throws -> Bool {
            switch payload {
                case .custom(let predicate):
                    return try predicate(message)
            }
        }
        
        public func callAsFunction(_ message: NetworkMessage) throws -> Bool {
            try matches(message)
        }
    }

}
