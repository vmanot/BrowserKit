//
// Copyright (c) Vatsal Manot
//

import Diagnostics
import Swallow
import WebKit

extension _BKWebView: Logging {
    class LoggingScriptMessageHandler: NSObject, WKScriptMessageHandler {
        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            if message.name == "logging" {
                print(message.body)
            }
        }
    }
}

extension WKWebViewConfiguration {
    func install(handler: _BKWebView.LoggingScriptMessageHandler) {
        let overrideConsole = """
            function log(emoji, type, args) {
              window.webkit.messageHandlers.logging.postMessage(
                `${emoji} JS ${type}: ${Object.values(args)
                  .map(v => typeof(v) === "undefined" ? "undefined" : typeof(v) === "object" ? JSON.stringify(v) : v.toString())
                  .map(v => v.substring(0, 3000)) // Limit msg to 3000 chars
                  .join(", ")}`
              )
            }
        
            let originalLog = console.log
            let originalWarn = console.warn
            let originalError = console.error
            let originalDebug = console.debug
        
            console.log = function() { log("📗", "log", arguments); originalLog.apply(null, arguments) }
            console.warn = function() { log("📙", "warning", arguments); originalWarn.apply(null, arguments) }
            console.error = function() { log("📕", "error", arguments); originalError.apply(null, arguments) }
            console.debug = function() { log("📘", "debug", arguments); originalDebug.apply(null, arguments) }
        
            window.addEventListener("error", function(e) {
               log("💥", "Uncaught", [`${e.message} at ${e.filename}:${e.lineno}:${e.colno}`])
            })
        """
        
        userContentController.addUserScript(
            WKUserScript(
                source: overrideConsole,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
    }
}
