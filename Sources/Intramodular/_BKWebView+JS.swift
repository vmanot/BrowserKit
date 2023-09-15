//
// Copyright (c) Vatsal Manot
//

import CorePersistence
import NetworkKit
import Swallow
import WebKit

extension _BKWebView {
    public func makeXMLHttpRequestUsingJavaScript(
        _ request: HTTPRequest
    ) async throws -> HTTPResponse {
        let request = try URLRequest(request)
        let url = try request.url.unwrap()
        let method = request.httpMethod ?? "GET"
        let body = request.httpBody.flatMap({ String(data: $0, encoding: .utf8) })
        let headers = request.allHTTPHeaderFields ?? [:]
        
        let js = """
            return await new Promise(function (resolve, reject) {
                var xhr = new XMLHttpRequest();
                xhr.open("\(method)", "\(request.url!.absoluteString)", true);
                \
                \(headers.map { "xhr.setRequestHeader(\"\($0.key)\", \"\($0.value)\");" }.joined(separator: "\n"))
                xhr.onload = function() {
                    var headers = {};
                    xhr.getAllResponseHeaders().trim().split(/\\n/).forEach(function (header) {
                        var parts = header.split(':');
                        var key = parts.shift().trim();
                        var value = parts.join(':').trim();
                        headers[key] = value;
                    });
                    var response = {
                        status: xhr.status,
                        statusText: xhr.statusText,
                        headers: headers,
                        body: xhr.responseText
                    };
                    resolve(JSON.stringify(response));
                };
                xhr.send(\(body.map({ "\"\($0)\"" }) ?? ""));
            });
        """
                
        let resultString = try await cast(callAsyncJavaScript(js, contentWorld: .page).unwrap(), to: String.self)
        
        let result = try cast(JSON(jsonString: resultString).toJSONObject().unwrap(), to: [String: Any].self)
        
        let resStatus = try cast(result["status"].unwrap(), to: Int.self)
        // let resStatusText = try cast(result["statusText"], to: String.self)
        let resHeaders = try cast(result["headers"], to: [String: String].self)
        let resBody = try result["body"].map({ try cast($0, to: String.self) })
        let resData = try resBody.unwrap().data(using: .utf8).unwrap()
        
        let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: resStatus,
            httpVersion: nil,
            headerFields: resHeaders
        )
        
        return try HTTPResponse(CachedURLResponse(response: httpResponse.unwrap(), data: resData))
    }
}
