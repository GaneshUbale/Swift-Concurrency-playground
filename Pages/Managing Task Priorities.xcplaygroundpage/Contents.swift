//: [Previous](@previous)
/*:
 # Lesson: Managing Task Priorities
 
 Swift Concurrency uses **Task Priorities** to give hints to the system's underlying thread scheduler about which work is most critical to perform first.
 
 ## Key Concepts
 
 * **Priority Levels**: Priority values range from highest (`.userInitiated`) to lowest (`.background`).
 * **Priority Inheritance**: Structured child tasks and standard `Task { }` instances inherit the priority of their parent context.
 * **Priority Escalation**: If a high-priority task awaits the result of a lower-priority task, the system temporarily escalates the lower-priority task to avoid delays.
 
 ---
 
 ## 1. Overview of Task Priority Levels
 
 Task priorities map directly to Quality of Service (QoS) levels:
 * `.high` / `.userInitiated`: Interactive or urgent tasks that block user interaction.
 * `.medium` / `.default`: Standard operations like processing non-urgent network requests.
 * `.low` / `.utility`: Long-running computational tasks like file exports or index updates.
 * `.background`: Non-urgent background work like database maintenance or syncs.
 */

// Explicitly creating an unstructured task with high priority
let highPriorityTask = Task(priority: .userInitiated) {
    print("High priority task running")
}

// Low-priority task for background syncs
let backgroundTask = Task(priority: .background) {
    print("Background sync task running")
}

/*:
 ## 2. Priority Inheritance in Child Tasks
 
 Child tasks automatically inherit their parent task's priority unless explicitly overridden.
 */

func processUserDashboard() async {
    // Current task inherits priority from caller
    print("Current task priority: \(Task.currentPriority)")
    
    // Child task inherits parent priority (.userInitiated)
    async let image = downloadAvatar()
    
    // Explicitly overriding priority for a low-urgency detached task
    Task.detached(priority: .background) {
        // Runs at .background priority, ignoring parent context
        print("Logging telemetry at background priority: \(Task.currentPriority)")
    }
}

func downloadAvatar() async -> String {
    return "Avatar Data"
}

Task {
    await processUserDashboard()
}
/*:
 ## 3. Priority Escalation
 
 When a high-priority task waits on a low-priority task using `await`, Swift automatically boosts the low-priority task's priority until execution finishes.
 */

func executeEscalationExample() async {
    let lowPriorityTask = Task(priority: .background) {
        // Initially runs at .background, but escalates when awaited below
        print("Low priority task executing...")
        return 42
    }
    
    // Create a high-priority task that awaits the low-priority task
    Task(priority: .userInitiated) {
        // System automatically escalates lowPriorityTask to prevent starvation
        let result = await lowPriorityTask.value
        print("High priority task received result: \(result)")
    }
}

Task {
    await executeEscalationExample()
}
/*:
 ---
 ## 🧠 Mental Model
 
 Think of Task Priorities as **Airport Security Lines**:
 * **`.userInitiated` (Priority Line)**: Passengers with tight flight connections get routed straight to the front of security lines.
 * **`.background` (Economy / Bulk Baggage)**: Bulk baggage moves along steady conveyor belts when throughput is open—it gets there eventually, but yields to people rushing for flights.
 * **Priority Escalation**: If a VIP passenger (`.userInitiated`) needs a piece of luggage sitting in the regular conveyor belt line, security immediately speeds up processing that specific bag so the VIP isn't delayed.
 */

//: [Next](@next)
