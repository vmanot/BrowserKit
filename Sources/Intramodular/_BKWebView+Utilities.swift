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

  // Focus the element before modifying its value
  element.focus();

  // Set the value and defaultValue (if applicable)
  setNativeValue(element, text);
  if ('defaultValue' in element) {
    element.defaultValue = text;
  }

  // Trigger 'input' and 'change' events
  ['input', 'change'].forEach(eventType => {
    const event = new Event(eventType, { bubbles: true });
    element.dispatchEvent(event);
  });

  // Simulate a sequence of keyboard events to mimic user typing more closely
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

  // Submit the form if requested, with a slight delay to account for asynchronous processing
  if (shouldSubmit && element.form) {
    setTimeout(() => {
      try {
        element.form.requestSubmit();
      } catch (error) {
        console.error('Form submission failed', error);
      }
    }, 500); // Adjust the delay as needed
  }
}

function setNativeValue(element, value) {
    // Handle value property (for inputs, textareas, etc.)
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
        
        // Also dispatch change event for non-React handlers
        element.dispatchEvent(new Event("change", { target: element, bubbles: true }));
    }
    
    // Handle textContent property (for divs, spans, etc.)
    // Note: We still set this even if value exists since some elements can have both
    let lastTextContent = element.textContent;
    element.textContent = value;
    
    // Only dispatch textContent-related events if the content actually changed
    if (lastTextContent !== value) {
        // Trigger a mutation observer if any are watching
        let mutationEvent = new Event("DOMSubtreeModified", { target: element, bubbles: true });
        mutationEvent.simulated = true;
        element.dispatchEvent(mutationEvent);
        
        // For elements that don't have a value property but might be tracked by React
        if (!('value' in element)) {
            let textInputEvent = new Event("input", { target: element, bubbles: true });
            textInputEvent.simulated = true;
            element.dispatchEvent(textInputEvent);
        }
    }
}

return type(selector, text, shouldSubmit)
"""
