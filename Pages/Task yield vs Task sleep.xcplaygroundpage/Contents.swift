//: [Previous](@previous)
/*:
 # Lesson: `Task.yield()` vs. `Task.sleep()`
 
 Both `Task.yield()` and `Task.sleep()` suspend execution to let other tasks run, but they serve entirely different control-flow purposes in Swift Concurrency.
 
 ## Key Concepts
 
 * **`Task.yield()`**: Voluntarily suspends the current task to give equal- or higher-priority tasks a chance to execute on the cooperative thread pool before resuming immediately when threads are free.
 * **`Task.sleep()`**: Delays execution for a specific duration (or until a deadline), suspending the task for at least that time period.
 * **Cooperative Multitasking**: Long CPU-bound loops can starve other tasks on the thread pool unless interrupted with suspension points like `Task.yield()`.
 
 ---
 
 ## 1. Yielding Execution with `Task.yield()`
 
 Use `Task.yield()` inside tight, CPU-intensive loops to prevent thread starvation and give equal- or higher-priority tasks a turn on the execution pool.
 */

func processHeavyImageBatch(images: [String]) async {
    for (index, image) in images.enumerated() {
        // Perform CPU-bound processing
        print("Processing image \(image)")
        
        // Every 10 items, “pause and let others run; resume soon”
        if index % 10 == 0 {
            await Task.yield()
        }
    }
}


let images = ["a.jpg", "b.jpg", "c.jpg", "d.jpg"]

Task {
    await processHeavyImageBatch(images: images)
}

/*:
 ## 2. Delaying Execution with `Task.sleep()`
 
 Use `Task.sleep()` to pause work for a specific duration or deadline. `Task.sleep` checks for task cancellation automatically and throws `CancellationError` if canceled.
 */

func pollServerStatus() async throws {
    print("Checking server status...")
    
    // Modern Swift Duration syntax (Swift 5.7+)
    try await Task.sleep(for: .seconds(3))
    
    // Alternative clock-based sleep syntax
    try await Task.sleep(until: .now + .seconds(2), clock: .continuous)
    
    print("Server check complete.")
}

Task {
    do {
        try await pollServerStatus()
    } catch {
        print("Failed to check server status: \(error)")
    }
}
/*:
 ## 3. Comparison Summary
 
 ### `Task.yield()`
 * **Purpose:** Give other pending tasks a chance to run.
 * **Duration:** Suspends briefly, then resumes when the task is scheduled again.
 * **Error handling:** Does not throw.
 * **Use it for:** Periodically yielding during long-running CPU-bound loops.

 ### `Task.sleep()`
 * **Purpose:** Suspend the current task for a specified duration or until a deadline.
 * **Duration:** Suspends for at least the requested duration.
 * **Error handling:** Throws `CancellationError` if the task is canceled.
 * **Use it for:** Delays, polling intervals, timeouts, and debouncing.
 
 ---
 ## 🧠 Mental Model
 
 Think of thread management as **Sharing an Exercise Machine at the Gym**:
 * **`Task.yield()` (Stepping off between sets)**: You are using a bench press for a 100-rep marathon set. Every 10 reps, you step back to let another gym member perform a quick set (`Task.yield()`). If no one is waiting, you immediately hop back on.
 * **`Task.sleep()` (Setting a timer for a water break)**: You sit down on a bench, set a timer for 5 minutes (`Task.sleep(for: .seconds(300))`), and rest. You step off completely and refuse to use the machine until your timer goes off.
 */
//: [Next](@next)
