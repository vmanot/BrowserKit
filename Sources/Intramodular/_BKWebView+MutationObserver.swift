//
//  File.swift
//  BrowserKit
//
//  Created by Purav Manot on 30/04/25.
//

import Foundation
import Combine

extension _BKWebView {
    class MutationObserverScriptMessageHandler: NSObject, WKScriptMessageHandler {
        var htmlSourceSubject: PassthroughSubject<String, Never> = .init()

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "observation" else { return }
            
            guard let messageBody = message.body as? String else { return }
            
            htmlSourceSubject.send(messageBody)
        }
    }
}
extension WKWebViewConfiguration {
    func install(handler: _BKWebView.MutationObserverScriptMessageHandler) {
        let htmlObservation: String = """
        var observer = new MutationObserver(function(mutations) {
            window.webkit.messageHandlers.observation.postMessage(document.documentElement.outerHTML);
        });
        
        observer.observe(document.documentElement, { childList: true, subtree: true });
        """

        
        userContentController.addUserScript(WKUserScript(
            source: htmlObservation,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))
    }
}
