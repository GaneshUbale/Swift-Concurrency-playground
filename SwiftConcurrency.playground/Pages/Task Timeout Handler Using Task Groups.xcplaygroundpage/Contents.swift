//: [Previous](@previous)
/*:
 # Lesson: Task Timeout Handler Using Task Groups
 
 Standard Swift Concurrency does not feature a built-in `async` timeout modifier. However, you can construct a reusable, non-blocking **Timeout Handler** by running your target operation alongside a sleep task in a race using a **Throwing Task Group**.
 
 ## Key Concepts
 
 * **Concurrent Race**: Spawn two child tasks inside a `withThrowingTaskGroup` scope—one for the actual work, and one for a sleep delay timer.
 * **First Result Wins**: Await the completion of whichever child task finishes first, then explicitly cancel the remaining child task.
 * **Automatic Cancellation**: If the sleep task finishes first, throw a `TimeoutError` and trigger group cancellation to halt the pending work.
 
 ---
 
 ## 1. Defining a Timeout Error
 
 Create a custom error to distinguish timeouts from other task failures.
 */

enum TimeoutError: Error {
    case timedOut
}

/*:
 ## 2. Building the Generic `withTimeout` Function
 
 By combining generics and throwing task groups, you can wrap any async work with a custom deadline.
 */

func withTimeout<T: Sendable>(
    seconds: Double,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        // Child Task 1: Execute the actual asynchronous work
        group.addTask {
            return try await operation()
        }
        
        // Child Task 2: Execute the timeout clock
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            // If the clock runs out before operation finishes, throw TimeoutError
            throw TimeoutError.timedOut
        }
        
        // Await the outcome of whichever task finishes FIRST
        guard let result = try await group.next() else {
            throw TimeoutError.timedOut
        }
        
        // Cancel the losing task (e.g., stop the sleep timer if work succeeded early)
        group.cancelAll()
        
        return result
    }
}

/*:
 ## 3. Practical Usage Example
 
 Wrap network requests or slow computations inside `withTimeout`.
 */

func performSlowNetworkRequest() async throws -> String {
    // Simulates a slow 3-second network request
    try await Task.sleep(nanoseconds: 3_000_000_000)
    return "Data payload loaded successfully!"
}

func executeWithTimeoutExample() async {
    do {
        print("Starting task with a 1.5 second limit...")
        // This will time out because 3.0s work > 1.5s timeout
        let response = try await withTimeout(seconds: 1.5) {
            try await performSlowNetworkRequest()
        }
        print("Success: \(response)")
    } catch TimeoutError.timedOut {
        print("Operation timed out! Request was cancelled cleanly.")
    } catch {
        print("Failed with unexpected error: \(error)")
    }
}

Task {
    await executeWithTimeoutExample()
}
/*:
 ---
 ## 🧠 Mental Model
 
 Think of a Task Group Timeout as an **Egg Timer Race**:
 * **The Workers**: You place two workers in a room—Worker A (the operation) and Worker B (the countdown egg timer).
 * **The First to Finish**:
   * If Worker A finishes making the meal before the timer dings, they shout "Done!", you take the meal, and you cancel the timer (Worker B).
   * If the egg timer dings first (`TimeoutError`), Worker B alerts you, and you immediately yell "Time's up!" (`group.cancelAll()`) to make Worker A drop what they are doing and exit.
 */
//: [Next](@next)
