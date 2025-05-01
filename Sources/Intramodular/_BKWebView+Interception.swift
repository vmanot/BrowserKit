import Diagnostics
import SwiftUI
import Swallow
import NetworkKit
import WebKit

extension _BKWebView {
    class NetworkScriptMessageHandler: NSObject, WKScriptMessageHandler {
        public var handlers: IdentifierIndexingArrayOf<NetworkMessageHandler> = []
        
        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "network" else { return }
            
            guard let dict = message.body as? [String: Any] else {
                return
            }
            
            #try(.optimistic) {
                let data = try JSONSerialization.data(withJSONObject: dict)
                
                let networkMessage = try JSONDecoder().decode(NetworkMessage.self, from: data)
                
                for handler in self.handlers {
                    try handler(networkMessage)
                }
            }
        }
    }
    
    struct NetworkMessageHandler: Identifiable {
        var id = UUID()
        var action: (NetworkMessage) -> ()
        var predicate: _BKWebView.NetworkMessagePattern
        
        init(id: UUID = UUID(), predicate: _BKWebView.NetworkMessagePattern, action: @escaping (NetworkMessage) -> Void) {
            self.id = id
            self.predicate = predicate
            self.action = action
        }
        
        func callAsFunction(_ message: NetworkMessage) throws {
            if try predicate.matches(message) {
                self.action(message)
            }
        }
    }
    
    public struct NetworkMessage: Decodable {
        public enum MessageType: String, Decodable {
            case fetch
            case fetchResponse
            case fetchError
            case xhr
            case xhrResponse
            case xhrError
            case xhrAbort
        }
        
        public let type: MessageType
        public let method: String?
        public let url: String
        public let body: [String: Any]?
        public let status: Int?
        public let response: String?
        public let error: String?
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            type = try container.decode(MessageType.self, forKey: .type)
            method = try container.decodeIfPresent(String.self, forKey: .method)
            url = try container.decode(String.self, forKey: .url)
            status = try container.decodeIfPresent(Int.self, forKey: .status)
            error = try container.decodeIfPresent(String.self, forKey: .error)
            
            if let rawBody = try container.decodeIfPresent(AnyCodable.self, forKey: .body) {
                body = rawBody.value as? [String: Any]
            } else {
                body = nil
            }
            
            response = try container.decodeIfPresent(String.self, forKey: .response)
        }
        
        enum CodingKeys: String, CodingKey {
            case type, method, url, body, status, response, error
        }
    }
}

extension WKWebViewConfiguration {
    func install(handler: _BKWebView.NetworkScriptMessageHandler) {
        let interceptNetwork = """
        (function() {
        const stringify = (value) => {
        try {
            return JSON.stringify(value);
        } catch {
            return String(value);
        }
        };
        
        const postMessage = (data) => {
        try {
            window.webkit?.messageHandlers?.network?.postMessage(data);
        } catch (e) {
            console.error("WKWebView message post failed:", e, data);
        }
        };
        
        const safeClone = async (response) => {
        try {
            const contentType = response.headers.get("content-type") || "";
            if (contentType.includes("application/json")) {
                const json = await response.clone().json();
                return stringify(json);
            } else if (contentType.includes("text") || contentType.includes("html")) {
                return await response.clone().text();
            } else {
                return "[non-textual response]";
            }
        } catch {
            return "[unreadable response]";
        }
        };
        
        const originalFetch = window.fetch;
        window.fetch = async function(...args) {
        const [resource, config] = args;
        const method = (config && config.method) || 'GET';
        const body = config && config.body;
        
        postMessage({
            type: 'fetch',
            method,
            url: resource,
            body: stringify(body ?? null)
        });
        
        try {
            const response = await originalFetch.apply(this, args);
            const responseBody = await safeClone(response);
        
            postMessage({
                type: 'fetchResponse',
                url: resource,
                status: response.status,
                response: responseBody
            });
        
            return response;
        } catch (error) {
            postMessage({
                type: 'fetchError',
                url: resource,
                error: String(error?.message || error)
            });
            throw error;
        }
        };
        
        const originalXHR = window.XMLHttpRequest;
        function CustomXHR() {
        const xhr = new originalXHR();
        
        xhr.open = new Proxy(xhr.open, {
            apply(target, thisArg, argArray) {
                thisArg._method = argArray[0];
                thisArg._url = argArray[1];
                return target.apply(thisArg, argArray);
            }
        });
        
        xhr.send = new Proxy(xhr.send, {
            apply(target, thisArg, argArray) {
                const body = argArray[0];
                postMessage({
                    type: 'xhr',
                    method: thisArg._method,
                    url: thisArg._url,
                    body: stringify(body ?? null)
                });
                return target.apply(thisArg, argArray);
            }
        });
        
        xhr.addEventListener('load', function() {
            let responseText = xhr.responseText;
            try {
                responseText = stringify(JSON.parse(responseText));
            } catch {
                // use original string
            }
        
            postMessage({
                type: 'xhrResponse',
                url: xhr.responseURL,
                status: xhr.status,
                response: responseText
            });
        });
        
        xhr.addEventListener('error', function() {
            postMessage({
                type: 'xhrError',
                url: xhr.responseURL,
                error: 'Network error'
            });
        });
        
        xhr.addEventListener('abort', function() {
            postMessage({
                type: 'xhrAbort',
                url: xhr.responseURL
            });
        });
        
        return xhr;
        }
        
        window.XMLHttpRequest = CustomXHR;
        })();

        """
        
        userContentController.addUserScript(WKUserScript(
            source: interceptNetwork,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))
    }
}
