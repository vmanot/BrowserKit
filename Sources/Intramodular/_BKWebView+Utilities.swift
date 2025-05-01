//
// Copyright (c) Vatsal Manot
//

import Swallow

extension _BKWebView {
    public func currentHTML() async throws -> String {
        try await load()
        
        let result = try await evaluateJavaScript("document.documentElement.outerHTML.toString()")
        
        return try cast(result, to: String.self)
    }
    
    public func type(_ text: String, selector: String, shouldSubmit: Bool = false) async throws {
        try await self.callAsyncJavaScript(typeTextJS, arguments: ["selector": selector, "text": text, "shouldSubmit": shouldSubmit], contentWorld: .defaultClient)
    }
}

fileprivate let typeTextJS = """
function type(selector, text, shouldSubmit = false) {
  const element = document.querySelector(selector);
  
  if (!element) {
    console.warn('Element not found');
    return;
  }

  element.focus();

  setNativeValue(element, text);
  if ('defaultValue' in element) {
    element.defaultValue = text;
  }

  ['input', 'change'].forEach(eventType => {
    const event = new Event(eventType, { bubbles: true });
    element.dispatchEvent(event);
  });

  ['keydown', 'keypress', 'keyup'].forEach(eventType => {
    const keyboardEvent = new KeyboardEvent(eventType, {
      key: 'Enter',
      code: 'Enter',
      keyCode: 13,
      which: 13,
      bubbles: true,
    });
    element.dispatchEvent(keyboardEvent);
  });

  if (shouldSubmit && element.form) {
    setTimeout(() => {
      try {
        element.form.requestSubmit();
      } catch (error) {
        console.error('Form submission failed', error);
      }
    }, 500);
  }
}

function setNativeValue(element, value) {
    if ('value' in element) {
        let lastValue = element.value;
        element.value = value;
        
        let inputEvent = new Event("input", { target: element, bubbles: true });
        // React 15
        inputEvent.simulated = true;
        // React 16
        let tracker = element._valueTracker;
        if (tracker) {
            tracker.setValue(lastValue);
        }
        element.dispatchEvent(inputEvent);
        
        element.dispatchEvent(new Event("change", { target: element, bubbles: true }));
    }
    
    let lastTextContent = element.textContent;
    element.textContent = value;
    
    if (lastTextContent !== value) {
        let mutationEvent = new Event("DOMSubtreeModified", { target: element, bubbles: true });
        mutationEvent.simulated = true;
        element.dispatchEvent(mutationEvent);
        
        if (!('value' in element)) {
            let textInputEvent = new Event("input", { target: element, bubbles: true });
            textInputEvent.simulated = true;
            element.dispatchEvent(textInputEvent);
        }
    }
}

return type(selector, text, shouldSubmit)
"""
