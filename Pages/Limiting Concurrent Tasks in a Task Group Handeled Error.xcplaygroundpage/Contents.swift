//: [Previous](@previous)
/*:
 # Lesson: Limiting Concurrent Tasks in a Task Group (Advanced)
 
 By default, adding tasks to a `TaskGroup` using `group.addTask` runs all added tasks concurrently. If you add hundreds of tasks at once, this can exhaust memory or hit network rate limits. Limiting maximum concurrency throttles task execution and protects system resources.
 
 ## Key Concepts
 
 * **Concurrency Throttle**: Restrict the maximum number of active child tasks running simultaneously.
 * **Sliding Window Pattern**: Enqueue child tasks up to a set capacity limit, then `await` completing tasks before adding new ones.
 * **Graceful Failure Handling**: Wrapping task operations in `Result<Success, Failure>` prevents a single failed task from throwing an error and blowing up the entire batch.
 
 ---
 
 ## 1. Throttled Task Group with Graceful Failure Handling
 
 Using `Result<R, Error>` inside a non-throwing `withTaskGroup` lets you catch individual errors per item without triggering automatic group cancellation.
 */

func processItemsWithThrottling<T: Sendable, R: Sendable>(
    items: [T],
    maxConcurrentTasks: Int,
    operation: @escaping @Sendable (T) async -> Result<R, Error>
) async -> [Result<R, Error>] {
    await withTaskGroup(of: Result<R, Error>.self) { group in
        var results: [Result<R, Error>] = []
        var activeTaskCount = 0
        
        for item in items {
            // When reaching maximum capacity, wait for at least one active task to finish
            if activeTaskCount >= maxConcurrentTasks {
                if let completedResult = await group.next() {
                    results.append(completedResult)
                    activeTaskCount -= 1
                }
            }
            
            // Add the next child task to the group queue
            group.addTask {
                await operation(item)
            }
            activeTaskCount += 1
        }
        
        // Collect all remaining in-flight child task results
        for await result in group {
            results.append(result)
        }
        
        return results
    }
}

/*:
 ## 2. Practical Example: Batch Fetching Network Requests
 
 Process 10 items with a limit of 3 active tasks. If item 4 fails, it yields a `.failure` result without stopping the rest of the queue.
 */

enum NetworkError: Error {
    case serverError
}

func fetchItemData(id: Int) async -> Result<String, Error> {
    print("Started processing item \(id)")
    try? await Task.sleep(nanoseconds: 500_000_000) // Simulate network delay
    
    // Simulate intermittent failure for item 4
    if id == 4 {
        print("❌ Item \(id) failed!")
        return .failure(NetworkError.serverError)
    }
    
    print("✅ Finished processing item \(id)")
    return .success("Data Payload \(id)")
}

func executeBatchJob() async {
    let itemIDs = Array(1...10)
    
    let batchResults = await processItemsWithThrottling(
        items: itemIDs,
        maxConcurrentTasks: 3
    ) { id in
        await fetchItemData(id: id)
    }
    
    // Inspect individual successes and failures
    let successes = batchResults.compactMap { try? $0.get() }
    let failures = batchResults.compactMap { result -> Error? in
        if case .failure(let error) = result {
            return error }
        return nil
    }
    
    print("Batch Complete! Successful: \(successes.count), Failed: \(failures.count)")
}

Task {
    await executeBatchJob()
}
/*:
 ---
 ## 🧠 Mental Model
 
 Think of this pattern as a **Bouncer at a Dining Room**:
 * **Capacity Limit (`maxConcurrentTasks = 3`)**: The room only has 3 dining tables.
 * **One-In, One-Out**: When table 4 arrives, they wait outside until table 1 or 2 finishes eating (`await group.next()`).
 * **Graceful Failures (`Result`)**: If a diner at table 4 drops their plate (`.failure`), the waiter clears the table, marks down "Order Failed", and immediately lets the next party outside sit down without shutting down the entire restaurant.
 */
//: [Next](@next)
