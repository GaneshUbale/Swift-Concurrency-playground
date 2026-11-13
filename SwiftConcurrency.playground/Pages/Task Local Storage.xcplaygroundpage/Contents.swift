//: [Previous](@previous)
/*:
 # Lesson: Task Local Storage using `@TaskLocal`
 
 **Task Local Values** allow you to attach metadata to the current asynchronous execution context. Child tasks automatically inherit task-local values from their parent, enabling context propagation (like request IDs, trace tokens, or auth credentials) without cluttering every function signature with extra parameters.
 
 ## Key Concepts
 
 * **`@TaskLocal` Property Wrapper**: Applied to `static` properties to declare a task-local variable.
 * **Scoped Binding via `$variable.withValue(_:operation:)`**: Sets the task-local value for the duration of a single execution scope.
 * **Automatic Inheritance**: Structured child tasks (`async let`, `TaskGroup`) and standard `Task { }` inherit task-local values from the parent scope.
 
 ---
 
 ## 1. Declaring a Task Local Property
 
 Declare a `static var` on an enum or struct and mark it with the `@TaskLocal` property wrapper.
 */

enum LoggerContext {
    // Must be a static property and optional (or have a default value)
    @TaskLocal static var traceID: String?
}

func logMessage(_ message: String) {
    // Access the current task-local value dynamically anywhere in the call hierarchy
    let currentTrace = LoggerContext.traceID ?? "NO_TRACE_ID"
    print("[\(currentTrace)] \(message)")
}

/*:
 ## 2. Binding Task Local Values
 
 Use the projected wrapper (`$traceID.withValue`) to assign a value. The value remains active only for the duration of the closure block.
 */

func processRequest() async {
    logMessage("Outside task-local scope") // Outputs: [NO_TRACE_ID] Outside task-local scope
    
    // Bind a trace ID for this specific scope
    await LoggerContext.$traceID.withValue("REQ-12345") {
        logMessage("Starting request processing") // Outputs: [REQ-12345] Starting request processing
        await performSubtask()
    }
    
    logMessage("Finished scope") // Automatically reverts back to nil
}

func performSubtask() async {
    logMessage("Inside subtask execution") // Outputs: [REQ-12345] Inside subtask execution
}

// Run the task-local request example
Task {
    await processRequest()
}

/*:
 ## 3. Inheritance Across Child Tasks
 
 Task-local values automatically propagate down into structured child tasks and standard `Task { }` blocks.
 */

func handleConcurrentSubrequests() async {
    await LoggerContext.$traceID.withValue("TRACE-888") {
        // Structured concurrency inherits task-local context
        async let first = performSubtask()
        async let second = performSubtask()
        
        _ = await (first, second)
        
        // Unstructured tasks inherit context as well
        Task {
            logMessage("Unstructured task execution") // Outputs: [TRACE-888] Unstructured task execution
        }
    }
}

// Run the structured child-task example
Task {
    await handleConcurrentSubrequests()
}

/*:
 ---
 ## 🧠 Mental Model
 
 Think of Task Local Storage as an **Invisible VIP Lanyard**:
 * **Putting on the Lanyard (`withValue`)**: When you enter a secured room (`withValue`), you put on a lanyard stamped with a Request ID.
 * **Passing Down**: Anyone who works under you in that room or joins your sub-team (child tasks) automatically gets a duplicate lanyard stamped with the same ID.
 * **Exiting Scope**: Once you step out of that specific room, you take off the lanyard and your identity reverts back to normal.
 */
//: [Next](@next)
