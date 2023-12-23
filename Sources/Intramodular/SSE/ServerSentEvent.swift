//
// Copyright (c) Vatsal Manot
//

import Swallow

public enum ServerSentEvent {
    case event(id: String?, event: String?, data: String?, time: String?)
    
    init?(
        eventString: String?,
        newLineCharacters: [Character]
    ) {
        guard let eventString = eventString else { return nil }
        
        if eventString.hasPrefix(":") {
            return nil
        }
        
        self = ServerSentEvent.parseEvent(eventString, newLineCharacters: newLineCharacters)
    }
    
    public var id: String? {
        guard case let .event(eventId, _, _, _) = self else {
            return nil
        }
        return eventId
    }
    
    public var event: String? {
        guard case let .event(_, eventName, _, _) = self else {
            return nil
        }
        
        return eventName
    }
    
    public var data: String? {
        guard case let .event(_, _, eventData, _) = self else {
            return nil
        }
        
        return eventData
    }
    
    public var retryTime: Int? {
        guard case let .event(_, _, _, aTime) = self, let time = aTime else {
            return nil
        }
        
        return Int(time.trimmingCharacters(in: CharacterSet.whitespaces))
    }
    
    public var onlyRetryEvent: Bool? {
        guard case let .event(id, name, data, time) = self else {
            return nil
        }
        
        let otherThanTime = id ?? name ?? data
        
        if otherThanTime == nil && time != nil {
            return true
        }
        
        return false
    }
}

extension ServerSentEvent {
    fileprivate static func parseEvent(
        _ eventString: String,
        newLineCharacters: [Character]
    ) -> ServerSentEvent {
        var event: [String: String?] = [:]
        
        let lines = eventString.components(separatedBy: CharacterSet.newlines)
        for (index, line) in lines.enumerated() {
            let (key, value) = ServerSentEvent.parseLine(line, index: index, lines: lines, newLineCharacters: newLineCharacters)
            guard let key = key else { continue }
            
            if let value = value, let previousValue = event[key] ?? nil {
                event[key] = "\(previousValue)\n\(value)"
            } else if let value = value {
                event[key] = value
            } else {
                event[key] = nil
            }
        }
        
        // the only possible field names for events are: id, event and data. Everything else is ignored.
        return .event(
            id: event["id"] ?? nil,
            event: event["event"] ?? nil,
            data: event["data"] ?? nil,
            time: event["retry"] ?? nil
        )
    }
    
    fileprivate static func parseLine(
        _ line: String,
        index: Int,
        lines: [String],
        newLineCharacters: [Character]
    ) -> (key: String?, value: String?) {
        let components = line.components(separatedBy: ":")
        
        guard components.count > 1 else {
            if index == lines.count - 1 {
                return (nil, line.trimmingCharacters(in: .whitespaces))
            } else {
                return (nil, nil)
            }
        }
        
        let key = components[0].trimmingCharacters(in: .whitespaces)
        var value = components[1].trimmingCharacters(in: .whitespaces)
        
        if value.isEmpty {
            if index < lines.count - 1 {
                let remainingLines = lines[(index + 1)...].joined(separator: "\n")
                
                value = remainingLines
                    .components(separatedBy: CharacterSet(newLineCharacters))[0]
                    .trimmingCharacters(in: CharacterSet.whitespaces)
            }
        }
        
        return (key, value)
    }
}
