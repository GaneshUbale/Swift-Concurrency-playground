//: [Previous](@previous)
/*:
 # Lesson: Error Handling in Tasks
 
 Handling errors effectively in asynchronous code prevents unexpected crashes and ensures smooth recovery when network calls or background operations fail.
 
 ## Key Concepts
 
 * **Throwing Closures**: `Task` initializers can accept throwing closures (`Task { try await ... }`).
 * **Capturing Errors via `Task.value`**: Accessing a throwing task's `.value` property propagates the error to the calling site using `try await`.
 * **Handling Errors Internally vs. Externally**: You can catch errors inside the task body or handle them where the task result is awaited.
 
 ---
 
 ## 1. Catching Errors Inside a Task
 
 If a task performs isolated work, handle errors internally using a standard `do-catch` block.
 */

enum FileError: Error {
    case fileNotFound
}

func readFile() async throws -> String {
    throw FileError.fileNotFound
}

// Internal error handling
Task {
    do {
        let content = try await readFile()
        print("Content: \(content)")
    } catch {
        print("Handled inside task: \(error)")
    }
}

/*:
 ## 2. Propagating Errors with `Task.value`
 
 When creating an unstructured task that returns a value or throws, accessing `task.value` requires `try await`.
 */

func fetchRemoteConfiguration() async -> String {
    let task = Task { () -> String in
        // Imagine a network call throwing an error here
        try await readFile()
    }
    
    do {
        // Calling .value will re-throw the error caught inside the task
        let config = try await task.value
        return config
    } catch {
        print("Caught error from task result: \(error)")
        return "Default Configuration"
    }
}

Task {
    let config = await fetchRemoteConfiguration()
    print(config)
}



/*:
 ---
 ## 🧠 Mental Model
 
 Think of a `Task` like a **delivery runner**:
 * **Execution**: You send the runner to complete a errand in the background.
 * **Internal Catch**: The runner encounters a problem (e.g., store is closed) and decides on an alternative on the spot.
 * **External Catch (`.value`)**: The runner returns back to you, hands you a sealed package, or tells you face-to-face what went wrong when you ask for the result (`try await task.value`).
 */
//: [Next](@next)
