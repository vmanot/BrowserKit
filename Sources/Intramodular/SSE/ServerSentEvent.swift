//
// Copyright (c) Vatsal Manot
//

import Swallow

/// Represents a Server-Sent Event.
///
/// Server-Sent Events (SSE) is a server push technology enabling a client to receive automatic updates from a server via HTTP connection.
public enum ServerSentEvent {
    /// Represents an event with optional id, event name, data, and retry time.
    case event(id: String?, event: String?, data: String?, retry: String?)
    
    /// Creates a `ServerSentEvent` from a string representation.
    ///
    /// - Parameters:
    ///   - eventString: The string representation of the event.
    ///   - newLineCharacters: Characters to be considered as new lines.
    /// - Returns: A `ServerSentEvent` if the string is valid, `nil` otherwise.
    public init?(eventString: String?, newLineCharacters: [Character]) {
        guard let eventString = eventString, !eventString.hasPrefix(":") else { return nil }
        self = ServerSentEvent.parseEvent(eventString, newLineCharacters: newLineCharacters)
    }
    
    /// The ID of the event.
    public var id: String? {
        guard case let .event(id, _, _, _) = self else { return nil }
        return id
    }
    
    /// The name of the event.
    public var event: String? {
        guard case let .event(_, event, _, _) = self else { return nil }
        return event
    }
    
    /// The data associated with the event.
    public var data: String? {
        guard case let .event(_, _, data, _) = self else { return nil }
        return data
    }
    
    /// The retry time of the event, if specified.
    public var retryTime: Int? {
        guard case let .event(_, _, _, retry) = self, let retry = retry else { return nil }
        return Int(retry.trimmingCharacters(in: .whitespaces))
    }
    
    /// Indicates if the event only contains retry information.
    public var onlyRetryEvent: Bool {
        guard case let .event(id, event, data, retry) = self else { return false }
        return id == nil && event == nil && data == nil && retry != nil
    }
}

private extension ServerSentEvent {
    static func parseEvent(
        _ eventString: String,
        newLineCharacters: [Character]
    ) -> ServerSentEvent {
        var event: [String: String] = [:]
        let lines = eventString.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            let (key, value) = parseLine(line, index: index, lines: lines, newLineCharacters: newLineCharacters)
            if let key = key, let value = value {
                event[key] = event[key].map { $0 + "\n" + value } ?? value
            }
        }
        
        return .event(id: event["id"], event: event["event"], data: event["data"], retry: event["retry"])
    }
    
    static func parseLine(
        _ line: String,
        index: Int,
        lines: [String],
        newLineCharacters: [Character]
    ) -> (key: String?, value: String?) {
        let components = line.components(separatedBy: ":")
        guard components.count > 1 else {
            return (nil, index == lines.count - 1 ? line.trimmingCharacters(in: .whitespaces) : nil)
        }
        
        let key = components[0].trimmingCharacters(in: .whitespaces)
        var value = components[1].trimmingCharacters(in: .whitespaces)
        
        if value.isEmpty, index < lines.count - 1 {
            value = lines[(index + 1)...].joined(separator: "\n")
                .components(separatedBy: CharacterSet(newLineCharacters))[0]
                .trimmingCharacters(in: .whitespaces)
        }
        
        return (key, value)
    }
}
