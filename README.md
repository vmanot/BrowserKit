# Requirements

- Deployment target: iOS 16, macOS 13
- Xcode 15+

# Usage

The main export of this package is `BKWebView`.

## Bundled JavaScript libraries

### [`turndown.js`](https://github.com/mixmark-io/turndown)

Usage:
```swift
let turndown = await _TurndownJS()

let urlRequest = URLRequest(url: URL(string: "https://en.wikipedia.org/wiki/Web_scraping")!)
let htmlString = try await URLSession.shared.data(for: urlRequest).0.toString()

let markdown = try await turndown.convert(htmlString: htmlString)

print(markdown)
```
