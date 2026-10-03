//: [Previous](@previous)
/*:
 # Lesson: Task Groups
 
 **Task Groups** enable structured concurrency when you need to execute a dynamic number of tasks in parallel and gather their results. Unlike `async let`, which works with a fixed set of concurrent operations, Task Groups handle collections of arbitrary size while automatically managing child task lifecycles and cancellation.
 
 ## Key Concepts
 
 * **Structured Concurrency**: Child tasks created within a group are tied to the group's lifetime. The parent task will not proceed past the group scope until all child tasks complete.
 * **`withTaskGroup` vs. `withThrowingTaskGroup`**: Use `withTaskGroup` for non-throwing operations, or `withThrowingTaskGroup` if child tasks can throw errors.
 * **Dynamic Parallelism**: Ideal for processing arrays, fetching multiple URLs, or batching asynchronous operations.
 
 ---
 
 ## 1. Creating a Non-Throwing Task Group
 
 Use `withTaskGroup(of:returning:body:)` to specify the child task return type and accumulate results using `addTask`.
 */

func fetchUsernames(ids: [Int]) async -> [String] {
    await withTaskGroup(of: String.self) { group in
        for id in ids {
            group.addTask {
                // Simulate an async fetch for each ID
                return "User_\(id)"
            }
        }
        
        var results: [String] = []
        // Asynchronously iterate over child task results as they finish
        for await username in group {
            results.append(username)
        }
        return results
    }
}

Task {
    let usernames = await fetchUsernames(ids: [1, 2, 3])
    print("Fetched usernames: \(usernames)")
}

/*:
 ## 2. Handling Errors with `withThrowingTaskGroup`
 
 If child tasks can throw, use `withThrowingTaskGroup`. If any child task throws an unhandled error, remaining tasks in the group are automatically requested to cancel.
 */
import Foundation
enum FetchError: Error {
    case invalidID
}

func fetchImageData(urls: [String]) async throws -> [Data] {
    try await withThrowingTaskGroup(of: Data.self) { group in
        for url in urls {
            group.addTask {
                if url.isEmpty { throw FetchError.invalidID }
                return Data() // Simulating fetched data
            }
        }
        
        var allData: [Data] = []
        for try await data in group {
            allData.append(data)
        }
        return allData
    }
}

Task {
    do {
        let imageData = try await fetchImageData(urls: ["image-1", "image-2"])
        print("Fetched image data: \(imageData.count) item(s)")
    } catch {
        print("Failed to fetch image data: \(error)")
    }

    do {
        _ = try await fetchImageData(urls: [""])
    } catch FetchError.invalidID {
        print("Invalid image URL")
    } catch {
        print("Failed to fetch image data: \(error)")
    }
}

/*:
 ---
 ## 🧠 Mental Model
 
 Think of a **Task Group** as a **Project Manager and a Team of Workers**:
 * **Dispatching Work**: The PM (`withTaskGroup`) hires workers (`group.addTask`) for each item in a to-do list.
 * **Collecting Results**: As each worker finishes their specific job, they drop the finished product into an inbox (`for await result in group`). The PM waits until every worker has turned in their work before declaring the overall project complete.
 * **Cancellation**: If one worker encounters a critical failure (`throw`), the PM immediately alerts the rest of the team to stop working on their tasks.
 */
//: [Next](@next)
