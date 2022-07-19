//
//  GlobalChannel.swift
//  Scratch Paper
//
//  Created by Bingyi Billy Li on 2022/7/14.
//

import Cocoa

typealias AnyFunction = (KeyValuePairs<String, Any>) -> Any?

/// A dynamically callable wrapper class for closures.
@dynamicCallable
struct DynamicFunction {
    
    /// Name of the dynamic function.
    var name: String
    
    /// A function body.
    var body: AnyFunction
    
    /// The target object by which the function is registered.
    var target: AnyObject?
    
    @discardableResult
    func dynamicallyCall(withKeywordArguments args: KeyValuePairs<String, Any> = [:]) -> Any? {
        return self.body(args)
    }
    
}

/**
 An object used for reference-free communication between objects at a global scope.
 
 This object stores and manages globally accessible functions.
 
 - Note: No more than one unique instance of this object should be created.
 */
@dynamicMemberLookup
class GlobalChannel {
    
    ///  Registered functions.
    private var functions: [String : DynamicFunction] = [:]
    
    subscript(dynamicMember name: String) -> DynamicFunction? {
        return self.functions[name]
    }
    
    subscript(name: String) -> AnyFunction? {
        get {
            return self.functions[name]?.body
        }
        set {
            if let newBody = newValue {
                self.functions[name]?.body = newBody
            }
        }
    }
    
    /**
     Registers a globally-accessible function.
     
     - Parameters:
        - name: The name of the function.
        - target: The target object by which the function is registered.
        - function: The function body as a closure.
     */
    func registerFunction(withName name: String, target: AnyObject? = nil, _ function: @escaping AnyFunction) {
        if !self.functions.keys.contains(name)  {
            let dynamicFunction = DynamicFunction(name: name, body: function, target: target)
            self.functions[name] = dynamicFunction
        }
    }
    
    /**
     Deregisters a function by name.
     
     - Parameter name: The name of the function to be deregistered.
     */
    func deregisterFunction(ofName name: String) {
        self.functions.removeValue(forKey: name)
    }
    
    /**
     Deregisters all functions with a given target by which these functions are registered.
     
     - Parameter target: The common target object of the functions to be deregistered.
     */
    func deregisterAll(forTarget target: AnyObject?) {
        let functions = Array(self.functions.values)
        for index in 0..<self.functions.count {
            let function = functions[index]
            if function.target === target {
                self.functions.removeValue(forKey: function.name)
            }
        }
    }
    
}
