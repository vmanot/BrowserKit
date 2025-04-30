//
//  File.swift
//  BrowserKit
//
//  Created by Purav Manot on 29/04/25.
//

import Foundation
import Combine

extension _BKWebView {
    public func networkMessages(
        matching predicate: NetworkMessagePattern
    ) -> AnyPublisher<NetworkMessage, Never> {
        NetworkMessagePublisher(messageHandler: self.networkScriptMessageHandler, predicate: predicate)
            .share()
            .eraseToAnyPublisher()
    }
}


extension _BKWebView {
    fileprivate struct NetworkMessagePublisher: Publisher {
        typealias Output = NetworkMessage
        typealias Failure = Never
        
        private weak var messageHandler: _BKWebView.NetworkScriptMessageHandler?
        fileprivate let  predicate: NetworkMessagePattern
        
        func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            let subscription = NavigationEventSubscription(
                downstream: subscriber,
                messageHandler: messageHandler,
                predicate: predicate
            )
            
            subscriber.receive(subscription: subscription)
        }
        
        init(messageHandler: _BKWebView.NetworkScriptMessageHandler? = nil, predicate: NetworkMessagePattern) {
            self.messageHandler = messageHandler
            self.predicate = predicate
        }
    }
    
    private final class NavigationEventSubscription<S: Subscriber>: NSObject, Subscription where S.Input == NetworkMessage, S.Failure == Never {
        private var id = UUID()
        private var downstream: S?
        private weak var messageHandler: _BKWebView.NetworkScriptMessageHandler?
        private let predicate: NetworkMessagePattern
        private var demand: Subscribers.Demand = .none
        
        private var observing: Bool = false
        
        init(downstream: S,
             messageHandler: _BKWebView.NetworkScriptMessageHandler?,
             predicate: NetworkMessagePattern)
        {
            self.downstream = downstream
            self.messageHandler = messageHandler
            self.predicate = predicate
            super.init()
            
        }
        
        func request(_ newDemand: Subscribers.Demand) {
            demand += newDemand
            
            guard !observing else { return }
            
            observing = true
            
            let handler: NetworkMessageHandler = NetworkMessageHandler(id: id, predicate: predicate) { [weak self] message in
                guard let self = self else { return }
                
                guard self.demand > 0 || self.demand == .unlimited else { return }
                let additional = downstream?.receive(message) ?? .none
                
                if demand != .unlimited { demand -= 1 }
                demand += additional
            }
            
            messageHandler?.handlers.insert(handler)
        }
        
        func cancel() {
            messageHandler?.handlers.remove(elementIdentifiedBy: id)
            downstream = nil
        }
    }
}

