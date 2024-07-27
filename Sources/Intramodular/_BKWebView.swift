//
// Copyright (c) Vatsal Manot
//

import Combine
internal import Merge
import Swallow
import WebKit

@MainActor
open class _BKWebView: WKWebView {
    weak var coordinator: WebView._BKWebViewRepresentable.Coordinator?
    
    var _navigationState = _NavigationState()
    
    /// Used when `_BKWebView` is loading scripts with a `WKUIDelegate` hack..
    private var scriptContinuations: [String: CheckedContinuation<Void, Error>] = [:]
    private var userScriptContinuations: [String: CheckedContinuation<Void, Error>] = [:]
    
    public var navigationEvents: AnyAsyncSequence<Result<WKNavigation.Success, Error>> {
        get async {
            AnyAsyncSequence(await _navigationState.navigationEventsSubject.values)
        }
    }
    
    private let loggingScriptMessageHandler = LoggingScriptMessageHandler()
    
    @MainActor
    init() {
        HTTPCookieStorage.shared.cookieAcceptPolicy = .always
        
        let configuration = WKWebViewConfiguration()
        
        configuration.processPool = Self.ProcessPool.shared
        configuration.install(handler: loggingScriptMessageHandler)
        configuration.userContentController.add(loggingScriptMessageHandler, name: "logging")
        // configuration.userContentController.add(self, name: "scriptCallback")
        
        assert(configuration.processPool == Self.ProcessPool.shared)
        
        super.init(frame: .zero, configuration: configuration)
        
        self.navigationDelegate = self
        self.uiDelegate = self
        
        configuration.websiteDataStore.httpCookieStore.add(self)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented, init(frame:configurationBlock:)")
    }
    
    @MainActor
    @discardableResult
    open override func load(_ request: URLRequest) -> WKNavigation? {
        if let url = request.url {
            configuration.userContentController = userContentController(for: url)
        }
        
        let navigation = super.load(request)
        
        Task.detached {
            try await self.task(for: navigation)
        }
        
        return navigation
    }
    
    open override func goForward() -> WKNavigation? {
        let navigation = super.goForward()
        
        Task.detached {
            try await self.task(for: navigation)
        }
        
        return navigation
    }
    
    open override func goBack() -> WKNavigation? {
        let navigation = super.goBack()
        
        Task.detached {
            try await self.task(for: navigation)
        }
        
        return navigation
    }
    
    @MainActor
    open override func reload() -> WKNavigation? {
        let navigation = super.reload()
        
        Task.detached {
            try await self.task(for: navigation)
        }
        
        return navigation
    }
    
    @MainActor
    open override func reloadFromOrigin() -> WKNavigation? {
        let navigation = super.reloadFromOrigin()
        
        Task.detached {
            try await self.task(for: navigation)
        }
        
        return navigation
    }
    
    @MainActor
    func syncCookiesToSharedHTTPCookieStorage(webView: WKWebView) async {
        guard let url = url, let host = url.host else {
            return
        }
        
        let sharedStoredCookies = HTTPCookieStorage.shared.cookies(for: url)
        
        let cookies = await configuration.websiteDataStore.httpCookieStore.allCookies().filter {
            host.range(of: $0.domain) != nil || $0.domain.range(of: host) != nil
        }
        
        for cookie in cookies {
            if let sharedStoredCookies {
                sharedStoredCookies
                    .filter({ $0.name == cookie.name })
                    .forEach({ HTTPCookieStorage.shared.deleteCookie($0) })
            }
            
            HTTPCookieStorage.shared.setCookie(cookie)
        }
    }
}

extension _BKWebView {
    func task(
        for navigation: WKNavigation?
    ) async throws -> Task<WKNavigation.Success, Error> {
        return try await _navigationState.task(for: navigation.unwrap())
    }
    
    func asyncResult(
        for navigation: WKNavigation?
    ) async throws -> WKNavigation.Success {
        try await task(for: navigation).value
    }
}

extension _BKWebView: WKHTTPCookieStoreObserver {
    public func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        Task {
            coordinator?.cookies = await cookieStore.allCookies()
        }
    }
}

extension _BKWebView {
    @MainActor
    public func loadScript(
        _ script: String
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let id = UUID().uuidString
            
            Task { @MainActor in
                self.scriptContinuations[id] = continuation
                
                let html = String(
                    """
                    <body>
                        <script>\(script)</script>
                        <script>alert('\(id)')</script>
                    </body>
                    """
                )
                
                self.loadHTMLString(html, baseURL: nil)
            }
        }
    }
}

extension _BKWebView: WKUIDelegate {
    public func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo
    ) async {
        if let continuation = self.scriptContinuations[message] {
            continuation.resume(returning: ())
        }
    }
}

// MARK: - API

extension _BKWebView {
    @discardableResult
    @MainActor
    public func load() async throws -> WKNavigation.Success? {
        try await _navigationState.lastTask?.value
    }
    
    @discardableResult
    @MainActor
    public func load(_ urlRequest: URLRequest) async throws -> WKNavigation.Success {
        try await asyncResult(for: self.load(urlRequest))
    }
    
    @discardableResult
    @MainActor
    public func load(_ url: URL) async throws -> WKNavigation.Success {
        try await load(URLRequest(url: url))
    }
    
    @discardableResult
    @MainActor
    public func goForward() async throws -> WKNavigation.Success {
        try await asyncResult(for: self.goForward())
    }
    
    @discardableResult
    @MainActor
    public func goBack() async throws -> WKNavigation.Success {
        try await asyncResult(for: self.goBack())
    }
}

// MARK: - Auxiliary

extension _BKWebView {
    actor _NavigationState {
        enum Resolution: Sendable {
            case taskWasCancelled
            case wasOverridden(by: WKNavigation?)
            case result(Result<WKNavigation.Success, Error>)
        }
        
        enum _Error: Swift.Error {
            case overriden
            case navigationMismatch
            case foundExistingResolution(Resolution, for: WKNavigation)
        }
        
        let navigationEventsSubject = PassthroughSubject<Result<WKNavigation.Success, Error>, Never>()
        
        private var last: WKNavigation?
        private var lastResponse: WKNavigationResponse?
        private var continuations: [WKNavigation: CheckedContinuation<WKNavigation.Success, Error>] = [:]
        private var tasks: [WKNavigation: Task<WKNavigation.Success, Error>] = [:]
        private var resolutions: [WKNavigation: Resolution] = [:]
        
        var lastTask: Task<WKNavigation.Success, Error>? {
            get {
                guard let last, let lastTask = tasks[last] else {
                    return nil
                }
                
                return lastTask
            }
        }
        
        func task(for navigation: WKNavigation) -> Task<WKNavigation.Success, Error>  {
            if let task = tasks[navigation] {
                return task
            } else {
                return createTask(for: navigation)
            }
        }
        
        private func createTask(for navigation: WKNavigation) -> Task<WKNavigation.Success, Error> {
            let task = Task(priority: .userInitiated) {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<WKNavigation.Success, Error>) in
                    Task.detached {
                        await withTaskCancellationHandler {
                            await self.begin(navigation, with: continuation)
                        } onCancel: {
                            Task {
                                await self.resolve(navigation, with: .canceled)
                            }
                        }
                    }
                }
            }
            
            tasks[navigation] = task
            
            return task
        }
        
        func begin(
            _ navigation: WKNavigation?,
            with continuation: CheckedContinuation<WKNavigation.Success, Error>
        ) {
            Task {
                if let last = last {
                    await resolve(last, with: .error(_Error.overriden))
                }
                
                self.last = navigation
                self.continuations[navigation] = continuation
            }
        }
        
        func setLastResponse(_ response: WKNavigationResponse?) {
            self.lastResponse = response
        }
        
        func resolve(
            _ navigation: WKNavigation?,
            with result: TaskResult<Void, Error>
        ) async {
            guard let navigation else {
                return
            }
            
            if let existingResolution = resolutions[navigation] {
                switch existingResolution {
                    case .wasOverridden, .taskWasCancelled:
                        return
                    default:
                        let error = _Error.foundExistingResolution(existingResolution, for: navigation)
                        
                        return assertionFailure(error)
                }
            }
            
            guard let continuation = continuations[navigation] else {
                return
            }
            
            let navigationResult: Result<WKNavigation.Success, Error>
            
            assert(tasks[navigation] != nil)
            
            do {
                if let last = last, last != navigation {
                    navigationResult = .failure(_Error.navigationMismatch)
                } else {
                    _ = try result.get()
                    
                    navigationResult = await .success(.init(urlResponse: try lastResponse.unwrap().response))
                }
            } catch {
                navigationResult = .failure(error)
            }
            
            continuation.resume(with: navigationResult)
            
            navigationEventsSubject.send(navigationResult)
            
            last = nil
            lastResponse = nil
            continuations[navigation] = nil
            tasks[navigation] = nil
            
            switch result {
                case .canceled:
                    resolutions[navigation] = .taskWasCancelled
                default:
                    resolutions[navigation] = .result(navigationResult)
            }
        }
    }
    
    fileprivate final class ProcessPool: WKProcessPool {
        static let shared = ProcessPool()
    }
}

// MARK: - Helpers

extension HTTPCookie {
    private static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        
        return dateFormatter
    }()
    
    var javascriptString: String {
        if var properties = properties {
            properties.removeValue(forKey: .name)
            properties.removeValue(forKey: .value)
            
            return properties
                .reduce(into: ["\(name)=\(value)"]) { result, property in
                    result.append("\(property.key.rawValue)=\(property.value)")
                }
                .joined(separator: "; ")
        }
        
        var script = [
            "\(name)=\(value)",
            "domain=\(domain)",
            "path=\(path)"
        ]
        
        if isSecure {
            script.append("secure=true")
        }
        
        if let expiresDate = expiresDate {
            script.append("expires=\(HTTPCookie.dateFormatter.string(from: expiresDate))")
        }
        
        return script.joined(separator: "; ")
    }
}

extension WKHTTPCookieStore {
    public func deleteAllCookies() async {
        for cookie in await allCookies() {
            await deleteCookie(cookie)
        }
    }
}
