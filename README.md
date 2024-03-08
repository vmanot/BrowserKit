# BrowserKit

[![Build all  platforms](https://github.com/vmanot/BrowserKit/actions/workflows/swift.yml/badge.svg)](https://github.com/vmanot/BrowserKit/actions/workflows/swift.yml)

# Requirements

- Deployment target: iOS 16, macOS 13
- Xcode 15+

# Usage

The main export of this package is `BKWebView`.

## Bundled JavaScript libraries

### [`turndown.js`](https://github.com/mixmark-io/turndown)

turndown is an HTML to Markdown converter written in JavaScript. BrowserKit ships a minified version of `turndown.js` that makes it easy to scrape web pages using a modern Swift API: 

For example:
```swift
let turndown = await _TurndownJS()

let urlRequest = URLRequest(url: URL(string: "https://en.wikipedia.org/wiki/Web_scraping")!)
let htmlString = try await URLSession.shared.data(for: urlRequest).0.toString()

let markdown = try await turndown.convert(htmlString: htmlString)

print(markdown)
```
