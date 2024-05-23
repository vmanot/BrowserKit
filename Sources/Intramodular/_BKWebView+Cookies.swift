//
// Copyright (c) Vatsal Manot
//

internal import Merge
import Swallow
import WebKit

extension _BKWebView {
    public func updateCookies(_ cookies: [HTTPCookie]?) async {
        guard let cookies = cookies, cookies.isEmpty == false else {
            return
        }
        
        await withTaskGroup(of: Void.self) { group in
            for cookie in cookies {
                group.addTask {
                    await self.setCookie(cookie)
                }
            }
        }
    }
    
    public func setCookie(_ cookie: HTTPCookie) async {
        HTTPCookieStorage.shared.setCookie(cookie)
       
        await configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
    }
    
    public func deleteCookie(_ cookie: HTTPCookie) async {
        HTTPCookieStorage.shared.deleteCookie(cookie)
     
        await configuration.websiteDataStore.httpCookieStore.deleteCookie(cookie)
    }
    
    public func deleteAllCookies() async {
        HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)
       
        await configuration.websiteDataStore.httpCookieStore.deleteAllCookies()
    }
    
    func userContentController(for url: URL) -> WKUserContentController {
        let userContentController = configuration.userContentController
        
        guard let cookies = HTTPCookieStorage.shared.cookies(for: url), cookies.count > 0 else {
            return userContentController
        }
        
        // https://stackoverflow.com/a/32845148
        var scripts: [String] = ["var cookieNames = document.cookie.split('; ').map(function(cookie) { return cookie.split('=')[0] } )"]
        
        let now = Date()
        
        for cookie in cookies {
            if let expiresDate = cookie.expiresDate, now.compare(expiresDate) == .orderedDescending {
                Task {
                    await deleteCookie(cookie)
                }
                
                continue
            }
            
            scripts.append("if (cookieNames.indexOf('\(cookie.name)') == -1) { document.cookie='\(cookie.javascriptString)'; }")
        }
        
        let mainScript = scripts.joined(separator: ";\n")
        
        userContentController.addUserScript(
            WKUserScript(
                source: mainScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
        )
        
        return userContentController
    }
}
