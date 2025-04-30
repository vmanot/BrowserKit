import Diagnostics
import SwiftUI
import Swallow
import WebKit

extension _BKWebView {
    class NetworkScriptMessageHandler: NSObject, WKScriptMessageHandler {
        var handlers: [UUID: ContinuationPredicateContainer] = [:]
        
        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            if message.name == "network" {
                do {
                    let data = try JSONSerialization.data(withJSONObject: message.body, options: [])
                    let networkMessage = try JSONDecoder().decode(NetworkMessage.self, from: data)
                    
                    for (key, container) in handlers {
                        #try(.optimistic) {
                            if try container.predicate(networkMessage) {
                                container.continuation.resume(returning: networkMessage)
                                handlers.removeValue(forKey: key)
                            }
                        }
                    }
                } catch {
                    print(error)
                }
            }
        }
    }
    
    struct ContinuationPredicateContainer {
        var predicate: NetworkMessagePattern
        var continuation: CheckedContinuation<NetworkMessage, Swift.Error>
        
        init(predicate: NetworkMessagePattern, continuation: CheckedContinuation<NetworkMessage, Swift.Error>) {
            self.predicate = predicate
            self.continuation = continuation
        }
    }
}

extension WKWebViewConfiguration {
    func install(handler: _BKWebView.NetworkScriptMessageHandler) {
        let interceptNetwork = """
        (function() {
            const originalFetch = window.fetch;
            window.fetch = async function(...args) {
                const [resource, config] = args;
                const method = (config && config.method) || 'GET';
                const body = (config && config.body) || null;
        
                window.webkit.messageHandlers.network.postMessage({
                    type: 'fetch',
                    method: method,
                    url: resource,
                    body: body
                });
        
                try {
                    const response = await originalFetch.apply(this, args);
                    const cloned = response.clone();
                    const contentType = cloned.headers.get("content-type") || "";
                    let responseBody = "";
        
                    if (contentType.includes("application/json")) {
                        responseBody = await cloned.json();
                    } else if (contentType.includes("text") || contentType.includes("html")) {
                        responseBody = await cloned.text();
                    }
        
                    window.webkit.messageHandlers.network.postMessage({
                        type: 'fetchResponse',
                        url: resource,
                        status: response.status,
                        body: responseBody
                    });
        
                    return response;
                } catch (error) {
                    window.webkit.messageHandlers.network.postMessage({
                        type: 'fetchError',
                        url: resource,
                        error: error.message
                    });
                    throw error;
                }
            };
        
            const originalXHR = window.XMLHttpRequest;
            function CustomXHR() {
                const xhr = new originalXHR();
        
                const open = xhr.open;
                xhr.open = function(method, url, ...rest) {
                    this._method = method;
                    this._url = url;
                    return open.call(this, method, url, ...rest);
                };
        
                const send = xhr.send;
                xhr.send = function(body) {
                    window.webkit.messageHandlers.network.postMessage({
                        type: 'xhr',
                        method: this._method,
                        url: this._url,
                        body: body
                    });
                    return send.call(this, body);
                };
        
                xhr.addEventListener('load', function() {
                    window.webkit.messageHandlers.network.postMessage({
                        type: 'xhrResponse',
                        url: xhr.responseURL,
                        status: xhr.status,
                        response: xhr.responseText
                    });
                });
        
                xhr.addEventListener('error', function() {
                    window.webkit.messageHandlers.network.postMessage({
                        type: 'xhrError',
                        url: xhr.responseURL,
                        error: 'Network error'
                    });
                });
        
                xhr.addEventListener('abort', function() {
                    window.webkit.messageHandlers.network.postMessage({
                        type: 'xhrAbort',
                        url: xhr.responseURL
                    });
                });
        
                return xhr;
            }
            window.XMLHttpRequest = CustomXHR;
        })();
        """
        
        userContentController.addUserScript(
            WKUserScript(
                source: interceptNetwork,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
        )
    }
}

extension _BKWebView {
    public struct NetworkMessage: Codable {
        public enum MessageType: String, Codable {
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
        public let body: String?
        public let status: Int?
        public let response: String?
        public let error: String?
        
        public init(type: MessageType, method: String?, url: String, body: String?, status: Int?, response: String?, error: String?) {
            self.type = type
            self.method = method
            self.url = url
            self.body = body
            self.status = status
            self.response = response
            self.error = error
        }
    }
}

