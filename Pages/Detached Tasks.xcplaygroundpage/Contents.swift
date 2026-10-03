//: [Previous](@previous)
/*:
 # Lesson: Detached Tasks
 
 By default, creating a `Task` inherits the priority, actor context, and local values of its parent context. A **Detached Task** explicitly opts out of this inheritance, running completely independently.
 
 ## Key Concepts
 
 * **Inheritance Bypass**: `Task.detached` does **not** inherit the actor (e.g., `@MainActor`), priority, or task-local values from where it was created.
 * **Use Cases**: Best reserved for background operations that do not care about the current UI/actor state, such as caching data to disk or logging analytics.
 * **Explicit Configuration**: You must manually pass a priority if you want it to run at a specific level.
 
 ---
 
 ## 1. Creating a Detached Task
 
 Use `Task.detached` instead of `Task { }`.
 */

func logAnalyticsEvent(_ event: String) {
    // Unstructured Task: Inherits caller's context (e.g., MainActor if called from UI)
    Task {
        print("Standard task logging: \(event)")
    }
    
    // Detached Task: Completely unattached from caller's context
    Task.detached(priority: .background) {
        // Runs on a background thread regardless of where logAnalyticsEvent was called
        print("Detached task logging: \(event)")
    }
}

logAnalyticsEvent("Xyz Event")
/*:
 ## 2. Detached Tasks and `@MainActor`
 
 If you create a standard `Task` inside a MainActor-bound class or function, the task automatically runs on the Main Thread. A `Task.detached` breaks away from this requirement.
 */

@MainActor
class ProfileViewModel {
    func updateProfile() {
        // Standard Task inherits @MainActor -> Runs on Main Thread
        Task {
            print("UI Update on Main Thread")
        }
        
        // Detached Task ignores @MainActor -> Runs off Main Thread
        Task.detached(priority: .background) {
            // Expensive computation or file compression
            print("Heavy lifting off the Main Thread")
        }
    }
}

ProfileViewModel().updateProfile()
/*:
 ## 3. Returning Values from Detached Tasks
 
 Like standard tasks, detached tasks can return values and throw errors using `.value`.
 */

func computeHash(for data: String) async -> Int {
    let hashTask = Task.detached(priority: .userInitiated) {
        return data.hashValue
    }
    
    return await hashTask.value
}

Task {
    let value = await computeHash(for: "Ganesh")
    print("HashValue:\(value)")
}
/*:
 ---
 ## 🧠 Mental Model
 
 Think of standard `Task` vs `Task.detached` as **Delegation vs. Outsourcing**:
 * **Standard `Task` (Child/Sibling)**: You assign a chore to a teammate in your room. They inherit your room's environment, house rules, and working hours.
 * **Detached `Task` (Outsourced Contractor)**: You dispatch a job to a completely separate third-party vendor. They don't know where you are sitting, what your schedule is, or what rules your room follows—they just do the work independently and send back the result when finished.
 */
//: [Next](@next)
