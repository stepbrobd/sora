//
//  JSContext+Extensions.swift
//  Sora
//
//  Created by Hamzo on 19/03/25.
//

import JavaScriptCore

extension JSContext {
    func setupConsoleLogging() {
        let consoleObject = JSValue(newObjectIn: self)
        
        // Set up console.log
        let consoleLogFunction: @convention(block) (String) -> Void = { message in
            Logger.shared.log(message, type: "Debug")
        }
        consoleObject?.setObject(consoleLogFunction, forKeyedSubscript: "log" as NSString)
        
        // Set up console.error
        let consoleErrorFunction: @convention(block) (String) -> Void = { message in
            Logger.shared.log(message, type: "Error")
        }
        consoleObject?.setObject(consoleErrorFunction, forKeyedSubscript: "error" as NSString)
        
        self.setObject(consoleObject, forKeyedSubscript: "console" as NSString)
        
        // Global log function
        let logFunction: @convention(block) (String) -> Void = { message in
            Logger.shared.log("JavaScript log: \(message)", type: "Debug")
        }
        self.setObject(logFunction, forKeyedSubscript: "log" as NSString)
    }
    
    func setupNativeFetch() {
        let fetchNativeFunction: @convention(block) (String, [String: String]?, JSValue, JSValue) -> Void = { urlString, headers, resolve, reject in
            guard let url = URL(string: urlString) else {
                Logger.shared.log("Invalid URL", type: "Error")
                reject.call(withArguments: ["Invalid URL"])
                return
            }
            var request = URLRequest(url: url)
            if let headers = headers {
                for (key, value) in headers {
                    request.setValue(value, forHTTPHeaderField: key)
                }
            }
            let task = URLSession.cloudflareCustom.dataTask(with: request) { data, _, error in
                if let error = error {
                    Logger.shared.log("Network error in fetchNativeFunction: \(error.localizedDescription)", type: "Error")
                    reject.call(withArguments: [error.localizedDescription])
                    return
                }
                guard let data = data else {
                    Logger.shared.log("No data in response", type: "Error")
                    reject.call(withArguments: ["No data"])
                    return
                }
                if let text = String(data: data, encoding: .utf8) {
                    resolve.call(withArguments: [text])
                } else {
                    Logger.shared.log("Unable to decode data to text", type: "Error")
                    reject.call(withArguments: ["Unable to decode data"])
                }
            }
            task.resume()
        }
        self.setObject(fetchNativeFunction, forKeyedSubscript: "fetchNative" as NSString)
        
        let fetchDefinition = """
                        function fetch(url, headers) {
                            return new Promise(function(resolve, reject) {
                                fetchNative(url, headers, resolve, reject);
                            });
                        }
                        """
        self.evaluateScript(fetchDefinition)
    }
    
    func setupFetchV2() {
        let fetchV2NativeFunction: @convention(block) (String, [String: String]?, JSValue, JSValue) -> Void = { urlString, headers, resolve, reject in
            guard let url = URL(string: urlString) else {
                Logger.shared.log("Invalid URL", type: "Error")
                reject.call(withArguments: ["Invalid URL"])
                return
            }
            var request = URLRequest(url: url)
            if let headers = headers {
                for (key, value) in headers {
                    request.setValue(value, forHTTPHeaderField: key)
                }
            }
            let task = URLSession.cloudflareCustom.dataTask(with: request) { data, response, error in
                if let error = error {
                    Logger.shared.log("Network error in fetchV2NativeFunction: \(error.localizedDescription)", type: "Error")
                    reject.call(withArguments: [error.localizedDescription])
                    return
                }
                guard let data = data else {
                    Logger.shared.log("No data in response", type: "Error")
                    reject.call(withArguments: ["No data"])
                    return
                }
                
                // Just pass the raw data string and let JavaScript handle it
                if let text = String(data: data, encoding: .utf8) {
                    resolve.call(withArguments: [text])
                } else {
                    Logger.shared.log("Unable to decode data to text", type: "Error")
                    reject.call(withArguments: ["Unable to decode data"])
                }
            }
            task.resume()
        }
        self.setObject(fetchV2NativeFunction, forKeyedSubscript: "fetchV2Native" as NSString)
        
        // Simpler fetchv2 implementation with text() and json() methods
        let fetchv2Definition = """
            function fetchv2(url, headers) {
                return new Promise(function(resolve, reject) {
                    fetchV2Native(url, headers, function(rawText) {
                        const responseObj = {
                            _data: rawText,
                            text: function() {
                                return Promise.resolve(this._data);
                            },
                            json: function() {
                                try {
                                    return Promise.resolve(JSON.parse(this._data));
                                } catch (e) {
                                    return Promise.reject("JSON parse error: " + e.message);
                                }
                            }
                        };
                        resolve(responseObj);
                    }, reject);
                });
            }
        """
        self.evaluateScript(fetchv2Definition)
    }
    
    func setupBase64Functions() {
        // btoa function: converts binary string to base64-encoded ASCII string
        let btoaFunction: @convention(block) (String) -> String? = { data in
            guard let data = data.data(using: .utf8) else {
                Logger.shared.log("btoa: Failed to encode input as UTF-8", type: "Error")
                return nil
            }
            return data.base64EncodedString()
        }
        
        // atob function: decodes base64-encoded ASCII string to binary string
        let atobFunction: @convention(block) (String) -> String? = { base64String in
            guard let data = Data(base64Encoded: base64String) else {
                Logger.shared.log("atob: Invalid base64 input", type: "Error")
                return nil
            }
            
            return String(data: data, encoding: .utf8)
        }
        
        // Add the functions to the JavaScript context
        self.setObject(btoaFunction, forKeyedSubscript: "btoa" as NSString)
        self.setObject(atobFunction, forKeyedSubscript: "atob" as NSString)
    }
    
    // Helper method to set up all JavaScript functionality
    func setupJavaScriptEnvironment() {
        setupConsoleLogging()
        setupNativeFetch()
        setupFetchV2()
        setupBase64Functions()
    }
}
