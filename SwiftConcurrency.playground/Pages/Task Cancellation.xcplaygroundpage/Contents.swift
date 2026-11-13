//: [Previous](@previous)
/*:
 # Lesson: Task Cancellation
 
 Swift Concurrency uses **cooperative cancellation**. Canceling a task does not abruptly stop it mid-execution; instead, it sets a cancellation flag on the task. The code inside the task must explicitly check for this flag and stop its work cleanly.
 
 ## Key Concepts
 
 * **Cooperative Cancellation**: Tasks must actively check if they have been canceled.
 * **Cancellation Propagation**: Canceling a structured parent task automatically requests cancellation of its child tasks.
 * **Clean Cleanup**: Checking for cancellation allows you to release resources, close network connections, or save partial state before exiting.
 
 ---
 
 ## 1. Checking Cancellation with `Task.isCancelled`
 
 You can inspect `Task.isCancelled` inside a loop or long-running algorithm to exit early without throwing an error.
 */

func fetchDashboard(label: String, for seconds: Int) async throws {
    print("⏳\(label) dashboard: Starting.")
    for _ in 1...seconds {
        // Check if the surrounding task was requested to cancel
        if Task.isCancelled {
            print("❌\(label) dashboard: fetch cancelled early.......")
            // if you not throw or return then it continue till it complet and called multiple times
//            throw CancellationError()
            return
        }
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
    print("✅\(label) dashboard: fetch completed..")
}

func fetchDashboard1(label: String, for seconds: Int) async throws {
    print("⏳\(label) dashboard: Starting.")
 
    try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)) // System async funcs are already handeled for cancellation eg sleep, URL sesstions
    print("✅\(label) dashboard: fetch completed..")
}
/*:
 ## 2. Throwing on Cancellation with `Task.checkCancellation()`
 
 If you want a cancelled task to throw a `CancellationError` automatically, use `Task.checkCancellation()`.
 */


func fetchDashboard2(label: String, for seconds: Int) async throws {
    print("⏳\(label) dashboard: Starting.")
    try Task.checkCancellation() // this helps if cancel imidiatly
    try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    try Task.checkCancellation() // this helps if cancel before completion and after start. This pace is nessery as
    print("✅\(label) dashboard: fetch completed..")
}

//Task {
//    print("--- Task.checkCancellation() ---")
//    let downloadTask = Task {
//        do {
//            try await fetchDashboard2(label: "Marketing", for: 5)
//        } catch is CancellationError {
//            print("🛑 Dashboard loading failed or was cancelled.")
//        } catch {
//            print("Dashboard loading failed with error: \(error)")
//        }
//    }
//    downloadTask.cancel() // this gets calles in deinit() or if you want to restart so cancel previous and start gain
////    await downloadTask.value
//}

/*:
## 3. Cancellation Propagation in Structured Concurrency

 Structured child tasks inherit cancellation from their parent. The parent waits for the child task to finish winding down before it returns.
 */

// The main parent task 
let parentTask = Task {
    do {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await fetchDashboard2(label: "Sales", for: 1)
            }
            group.addTask {
                try await fetchDashboard2(label: "Marketing", for: 5)
            }
            group.addTask {
                try await fetchDashboard2(label: "Profile", for: 5)
            }
            // Wait for children to finish
            try await group.waitForAll()
        }
    } catch {
        print("🛑 Parent: Dashboard loading failed or was cancelled.")
    }
}
// Simulate the user clicking "Back" after 2 second
Task {
    // Cancel the main task after 2 seconds, which propagates to child tasks
    try? await Task.sleep(nanoseconds: 2_000_000_000)
    print("\n📱 User left the screen! Cancelling parent task...\n")
    parentTask.cancel()
}

/*:
 ## 4. Triggering and Handling Cancellation
 
 When you start an unstructured `Task`, calling `.cancel()` on its handle requests cancellation. Built-in async functions like `Task.sleep` automatically throw `CancellationError` when cancelled.
 */

func executeCancellationExample() async {
    let task = Task {
        do {
            print("Task started...")
            // Task.sleep automatically reacts to cancellation and throws CancellationError
            try await Task.sleep(nanoseconds: 2_000_000_000)
            print("Task finished.")
        } catch is CancellationError {
            print("Task caught cancellation gracefully!")
        } catch {
            print("Failed with error: \(error)")
        }
    }
    
    // Request cancellation before the sleep finishes
    task.cancel()
    
    await task.value // ensures waits for the task to finish and retrieves its result.
}

// Run the examples from the synchronous playground context.
Task {
    print("--- Unstructured task cancellation ---")
    await executeCancellationExample()
}

/*:
 ---
 ## 🧠 Mental Model

 Think of task cancellation as **Calling Off a Delivery**:
 * **Cooperative cancellation (A cancellation request)**: Calling `task.cancel()` is like calling the delivery service to say, “Please stop if you can.” It sets a cancellation request, but it does not forcibly interrupt work already in progress.
 * **`Task.isCancelled` (Checking the order status)**: Long-running code must check the cancellation flag and return early when it is safe to stop.
 * **`Task.checkCancellation()` (Refusing a canceled order)**: This check turns the cancellation request into a `CancellationError`, allowing the task to leave through normal error handling.
 * **Cancellation propagation (Canceling the whole delivery)**: When a structured parent task is canceled, its child tasks receive the cancellation request too, so the entire operation can wind down cleanly.
 */
//: [Next](@next)
