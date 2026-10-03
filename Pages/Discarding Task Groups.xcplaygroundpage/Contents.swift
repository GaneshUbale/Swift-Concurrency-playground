//: [Previous](@previous)
/*:
 # Lesson: Discarding Task Groups
 
 Standard task groups hold onto child task results until you consume them, which can lead to excessive memory growth when running continuous or high-volume background operations. Introduced in Swift 5.9, **Discarding Task Groups** automatically discard completed child task results, preventing memory buildup.
 
 ## Key Concepts
 
 * **Automatic Cleanup**: Completed child task results are immediately freed from memory rather than buffered in the group.
 * **`withDiscardingTaskGroup`**: Used for non-throwing jobs that produce no returned values.
 * **`withThrowingDiscardingTaskGroup`**: Used when child tasks can throw errors.
 * **Long-Running Work**: Ideal for persistent background processes, event loops, server connections, or continuous file parsing.
 
 ---
 
 ## 1. Using `withDiscardingTaskGroup`
 
 Unlike standard task groups, child tasks inside a discarding group return `Void`. You do not loop over results using `for await`.
 */

func processContinuousStream(events: [String]) async {
    await withDiscardingTaskGroup { group in
        for event in events {
            group.addTask {
                // Perform fire-and-forget work
                print("Processed event: \(event)")
                // Result is immediately discarded to save memory
            }
        }
    }
}

Task {
    await processContinuousStream(events: ["event-1", "event-2", "event-3"])
}

/*:
 ## 2. Handling Errors with `withThrowingDiscardingTaskGroup`
 
 When a child task inside a discarding group throws an error, the group automatically cancels all remaining child tasks and rethrows the error to the calling site.
 */

enum ProcessingError: Error {
    case invalidData
}
import Foundation

func logBatchData(items: [Data]) async throws {
    try await withThrowingDiscardingTaskGroup { group in
        for item in items {
            group.addTask {
                if item.isEmpty {
                    throw ProcessingError.invalidData
                }
                print("Logged \(item.count) bytes")
            }
        }
    }
}

Task {
    do {
        try await logBatchData(items: [Data("alpha".utf8), Data("beta".utf8)])
    } catch {
        print("Failed to log batch: \(error)")
    }

    do {
        try await logBatchData(items: [Data(), Data("beta".utf8)])
    } catch {
        print("Caught invalid data error: \(error)")
    }
}

/*:
 ---
 ## 🧠 Mental Model
 
 Think of a **Discarding Task Group** as an **Assembly Line Shredder vs. Storage Bin**:
 * **Standard Task Group (Storage Bin)**: As workers finish items, they store them in a bin for you to pick up later. If you process millions of items, the bin will overflow (high memory footprint).
 * **Discarding Task Group (Shredder/Disposal)**: Each finished item is immediately processed and dropped down a chute or recycled as soon as it's done. You don't hold onto old items—you care only that the work gets executed continuously without hoarding memory.
 */
//: [Next](@next)
