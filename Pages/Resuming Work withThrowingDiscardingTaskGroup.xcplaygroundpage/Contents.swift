//: [Previous](@previous)
/*:
 # Lesson: Resuming Work with `withThrowingDiscardingTaskGroup`
 
 Because `withThrowingDiscardingTaskGroup` automatically discards child task results to keep memory usage minimal, it does not maintain an internal list of succeeded or pending tasks.
 
 If a child task throws an error, the task group automatically cancels all remaining child tasks and rethrows the error to the calling context. To resume processing where you left off, you must maintain external tracking state using an **Actor**.
 
 ## Key Concepts
 
 * **No Group State**: The discarding task group won't tell you which tasks succeeded or failed.
 * **External Tracking**: Track completed items in a thread-safe data structure (like an `actor`) before or after each task finishes.
 * **Retry Loop**: Wrap the discarding group in a `do-catch` or `while` loop, filtering out completed items before re-launching the group.
 
 ---
 
 ## 1. Setting Up the State Tracker (Actor)
 
 An `actor` provides safe concurrent access so multiple child tasks can mark themselves as completed without causing data races.
 */

actor WorkTracker<ID: Hashable> {
    private(set) var completedIDs: Set<ID> = []
    
    func markCompleted(_ id: ID) {
        completedIDs.insert(id)
    }
    
    func pendingItems(from originalList: [ID]) -> [ID] {
        return originalList.filter { !completedIDs.contains($0) }
    }
}

/*:
 ## 2. Resuming Execution After an Error
 
 Here is how you can track completion and retry only the remaining work after a failure:
 */

enum ProcessingError: Error {
    case temporaryNetworkFailure
}

func processItem(id: Int) async throws {
    // Simulate intermittent failure
    if id == 3 {
        throw ProcessingError.temporaryNetworkFailure
    }
    print("Successfully processed item \(id)")
}

func processAllWithRetry(itemIDs: [Int]) async {
    let tracker = WorkTracker<Int>()
    var maxRetries = 3
    
    while maxRetries > 0 {
        // Find which items haven't completed yet
        let remainingIDs = await tracker.pendingItems(from: itemIDs)
        
        if remainingIDs.isEmpty {
            print("All items completed successfully!")
            break
        }
        
        do {
            try await withThrowingDiscardingTaskGroup { group in
                for id in remainingIDs {
                    group.addTask {
                        try await processItem(id: id)
                        // Mark work as complete on the actor after success
                        await tracker.markCompleted(id)
                    }
                }
            }
        } catch {
            maxRetries -= 1
            let finished = await tracker.completedIDs
            print("Group failed with error: \(error).")
            print("Completed so far: \(finished). Retrying remaining items...")
        }
    }
}

Task {
    await processAllWithRetry(itemIDs: [1, 2, 3, 4])
}

/*:
 ---
 ## 🧠 Mental Model
 
 Think of this pattern like a **Clipboard Checklist for an Automatic Shredder**:
 * **The Shredder (`withThrowingDiscardingTaskGroup`)**: Destroys completed paperwork as soon as it's processed so your desk stays clear. If a jam occurs, the machine halts completely and drops everything in progress.
 * **The Clipboard (`Actor`)**: Before a worker puts a document into the shredder, they place a checkmark next to that item's ID on a separate clipboard in your hand.
 * **The Retry Process**: When the line halts due to a failure, you look at your clipboard to see which IDs don't have checkmarks yet, load only those remaining items back onto the line, and restart the process.
 */
//: [Next](@next)
