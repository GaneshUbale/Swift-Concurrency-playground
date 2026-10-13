//: [Previous](@previous)
/*:
 # Lesson: Limiting Concurrent Tasks in a Task Group
 
 By default, adding tasks to a `TaskGroup` using `group.addTask` runs all added tasks concurrently. If you add hundreds or thousands of tasks at once, this can exhaust memory or hit API rate limits. Limiting the maximum number of concurrent tasks ensures controlled execution and efficient resource usage.
 
 ## Key Concepts
 
 * **Concurrency Throttle**: Restrict the maximum number of active child tasks running at any single time.
 * **Sliding Window Pattern**: Populate the task group up to a specified limit, then await completed tasks before enqueuing new ones.
 * **Resource Management**: Ideal for batch processing large arrays of files, images, or network downloads without overloading the system.
 
 ---
 
 ## 1. Implementing a Concurrency Limit Pattern
 
 To throttle a task group, track the number of active tasks and loop over child results as soon as the maximum limit is reached.
 */

func processItemsInBatches<T: Sendable, R: Sendable>(
    items: [T],
    maxConcurrentTasks: Int,
    operation: @escaping @Sendable (T) async -> R
) async -> [R] {
    await withTaskGroup(of: R.self) { group in
        var results: [R] = []
        var activeTaskCount = 0
        
        for item in items {
            // If we've reached our maximum limit, wait for at least one task to finish
            if activeTaskCount >= maxConcurrentTasks {
                if let completedResult = await group.next() {
                    results.append(completedResult)
                    activeTaskCount -= 1
                }
            }
            
            // Spawn the next child task
            group.addTask {
                await operation(item)
            }
            activeTaskCount += 1
        }
        
        // Collect all remaining active child task results after the loop finishes
        for await result in group {
            results.append(result)
        }
        
        return results
    }
}

/*:
 ## 2. Practical Example: Downloading Images in Batches
 
 Limit network calls to a maximum of 3 concurrent downloads at a time.
 */

func downloadImage(url: String) async -> String {
    print("Started downloading: \(url)")
    try? await Task.sleep(nanoseconds: 1_000_000_000)
    print("Finished downloading: \(url)")
    return "Data for \(url)"
}

func executeThrottledDownloads() async {
    let urls = (1...10).map { "https://example.com/image\($0).png" }
    
    // Process 10 download requests, but restrict to 3 parallel workers max
    let results = await processItemsInBatches(
        items: urls,
        maxConcurrentTasks: 3
    ) { url in
        await downloadImage(url: url)
    }
    
    print("All downloads completed. Total fetched: \(results.count)")
}

Task {
    await executeThrottledDownloads()
}
/*:
 ---
 ## 🧠 Mental Model
 
 Think of limiting task concurrency as a **Bouncer at a Nightclub**:
 * **Capacity Limit (`maxConcurrentTasks`)**: The club allows only 3 guests inside at a time.
 * **Filling the Room**: The bouncer lets 3 people through the door immediately.
 * **One-In, One-Out**: When a 4th person arrives, they must wait outside until someone inside leaves (`await group.next()`). Once a guest exits, the bouncer lets the next person in line enter.
 */
//: [Next](@next)
