//: [Previous](@previous)
/*:
 # Lesson: Using Immediate Tasks (`Task.immediate`)
 
 In standard Swift Concurrency, creating a `Task { }` enqueues work onto an executor to be scheduled later. Introduced in **Swift 6.2 (SE-0472)**, **Immediate Tasks** start executing synchronously on the calling thread right away until they hit their first actual suspension point (`await`).
 
 ## Key Concepts
 
 * **Synchronous Start**: `Task.immediate` bypasses queueing delays and begins execution on the calling executor instantly.
 * **Suspension Hand-off**: The task runs synchronously until its first active `await`. Once suspended, control yields back to the caller while the task finishes asynchronously.
 * **Overhang Avoidance**: Keep the synchronous portion short to avoid blocking the main thread before reaching suspension.
 
 ---
 
 ## 1. Standard `Task` vs. `Task.immediate`
 
 Standard `Task` schedules work asynchronously, whereas `Task.immediate` executes its initial lines before continuing past the task block.
 */

func compareTaskExecution() {
    print("1. Start")
    
    // Standard Task: Enqueued to run later on the executor
    Task {
        print("Standard Task (runs asynchronously later)")
    }
    
    // Immediate Task: Executes right away on the caller thread
    Task.immediate {
        print("2. Immediate Task (starts synchronously NOW)")
    }
    
    print("3. End")
}
compareTaskExecution()
// Output order:
// 1. Start
// 2. Immediate Task (starts synchronously NOW)
// 3. End
// Standard Task (runs asynchronously later)

/*:
 ## 2. Suspension Points and Execution Yield
 
 An immediate task runs synchronously **only up to its first suspension point**.
 */

func performFetch() async -> String {
    try? await Task.sleep(nanoseconds: 500_000_000)
    return "Fetched Data"
}

func loadContent() {
    print("A. Call start")
    
    Task.immediate {
        print("B. Inside immediate task BEFORE await")
        
        // Task suspends here! Control immediately yields back to loadContent()
        let data = await performFetch()
        
        print("D. Inside immediate task AFTER await: \(data)")
    }
    
    print("C. Call finished")
}

loadContent()
// Output order:
// A. Call start
// B. Inside immediate task BEFORE await
// C. Call finished
// D. Inside immediate task AFTER await: Fetched Data

/*:
 ## 3. Immediate Variant APIs
 
 Swift provides immediate equivalents across unstructured and structured contexts:
 * **`Task.immediateDetached`**: Starts running immediately without inheriting actor or task-local context.
 * **`group.addImmediateTask`**: Spawns an immediate child task inside a `TaskGroup`.
 */

func processDetachedJob() {
    Task.immediateDetached(priority: .background) {
        print("Immediate detached task started synchronously")
    }
}

/*:
 ---
 ## 🧠 Mental Model
 
 Think of Immediate Tasks as a **Drive-Thru Window**:
 * **Standard Task (`Task { }`)**: You pull into line, take a numbered ticket, and park in a bay. The kitchen processes your order whenever a cook becomes available.
 * **Immediate Task (`Task.immediate`)**: You pull up and hand the cashier your cup for coffee. They fill the cup right in front of you instantly (synchronous start). If you also order a burger that takes 5 minutes to grill (`await performFetch()`), they hand you the coffee immediately, clear you out of the line, and ask you to wait in parking space #2 while they finish the burger asynchronously.
 */
//: [Next](@next)
