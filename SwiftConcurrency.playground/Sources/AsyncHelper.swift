//
//  AsyncHelper.swift
//  
//
//  Created by Ganesh Ubale on 28/11/26.
//

import PlaygroundSupport

/// Runs an asynchronous operation and keeps the playground alive until it finishes.
///
/// Use this helper in playground pages that need to execute `async` or `throws`
/// code from top-level synchronous scope. Call it once at the top level of a
/// playground page, not from a function or type. It marks the current page for
/// indefinite execution, starts the operation in an unstructured task, and
/// finishes execution after the operation completes.
///
/// This is a playground lifecycle helper, not an app concurrency API. In app
/// code, use `Task` when unstructured asynchronous work is appropriate.
///
/// If `operation` throws, the helper prints the error to the console and still
/// finishes the playground execution.
///
/// - Parameter operation: The asynchronous operation to run. It can use
///   Swift concurrency APIs and may throw an error.
///
/// - Note: The operation is `@Sendable` and `@escaping`, so it may be invoked
///   later outside the scope in which `runAsync` was called. Captured values
///   should be safe to share across concurrency domains.
///
/// ## Example
/// ```swift
/// runAsync {
///     let value = try await fetchValue()
///     print(value)
/// }
/// ```
public func runAsync(_ operation: @escaping @Sendable () async throws -> Void) {
    PlaygroundPage.current.needsIndefiniteExecution = true
    
    Task {
        do {
            try await operation()
        } catch {
            print("Error: \(error)")
        }
        await MainActor.run {
            PlaygroundPage.current.finishExecution()
        }
    }
}
