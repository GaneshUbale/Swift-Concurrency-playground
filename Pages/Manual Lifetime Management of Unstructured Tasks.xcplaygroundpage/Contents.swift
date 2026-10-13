//: [Previous](@previous)
/*:
 # Lesson: Manual Lifetime Management of Unstructured Tasks
 
 Unstructured tasks (`Task` and `Task.detached`) do not have a parent context managing their lifecycle. Because they can easily outlive the scope or class where they were created, you must handle task cancellation manually and explicitly avoid **retain cycles**.
 
 ## Key Concepts
 
 * **Explicit Cancellation**: Hold a reference to `Task<Success, Failure>` so you can trigger `.cancel()` when the enclosing object deinitializes or state changes.
 * **Strong Captures vs. Retain Cycles**: A task that strongly captures `self` keeps it alive until the task completes. This is a retain cycle only if `self` also retains the task handle.
 * **Using `[weak self]`**: Capture `self` weakly inside the task closure to allow objects to deallocate cleanly when dismissed.
 * **SwiftUI `.task` Modifier**: Binds the life of an asynchronous task directly to a View's lifecycle, automatically cancelling the task when the view disappears.
 * **Cancellation Tokens / Task Collectors**: Aggregate multiple task handles into a container object that cancels all tasks upon deallocation.
 * **Actor Isolation without Retain Cycles**: Restructuring state updates to reduce long-lived strong references to class instances.
  
 
 ---
 
 ## 1. Basic Retain Cycle Pitfall vs. `[weak self]`
 
 A strong capture keeps `self` alive until the task completes. It is a retain cycle only if `self` also owns the task handle; even without a cycle, a task that never finishes can keep `self` alive indefinitely.
 */

class DataFetcher {
    var data: String = ""
    
    // ⚠️ Strong capture extends self's lifetime until this task completes; it is not a cycle here
    func fetchUnsafe() {
        // Swift 6 can reject this when strict concurrency checks treat the closure as a concurrent
        // transfer of mutable, non-Sendable self. Swift 5 may warn with complete checking; older
        // compilers or weaker checking may not diagnose it, but the data-race risk remains.
//        Task {
//            try? await Task.sleep(nanoseconds: 5_000_000_000)
//            self.data = "Downloaded Content"
//        }
    }
    
    // ✅ SAFE: Use [weak self] and check for cancellation early
    func fetchSafe() {
        // Swift 6 strict concurrency can also reject this weak capture: weak self is still a
        // reference to this non-Sendable instance crossing into the concurrently executing task.
        // Swift 5 may warn with complete checking; older/weaker checks may not diagnose it.
//        Task { [weak self] in
//            try? await Task.sleep(nanoseconds: 5_000_000_000)
//            guard let self = self, !Task.isCancelled else { return }
//            self.data = "Downloaded Content"
//        }
    }
    
    // ✅ Main-actor isolated, and weakly captures self so the task does not extend its lifetime
    @MainActor
    func fetchSafeMainActor() {
        Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 5_000_000_000)
            } catch {
                return
            }
            guard let self else { return }
            self.data = "Downloaded Content"
        }
    }
}

// Example caller
Task { @MainActor in
    let fetcher = DataFetcher()
    fetcher.fetchSafeMainActor()
    try? await Task.sleep(nanoseconds: 500_000_000)
    print(fetcher.data)
}

/*:
 ## 2. Manual Lifetime Management with `Task.detached`
 
 `Task.detached` operates off the main thread and actor context, but it has the exact same retain cycle risks. Store the handle and cancel it during `deinit`.
 */
import Foundation
@MainActor
class HeavyProcessingEngine  {
    private var processingTask: Task<Void, Never>?
    
    func startBackgroundWork(dataBuffer: [Data]) {
        // Cancel existing task before starting a new one
        processingTask?.cancel()
        
        // Detached task doesn't inherit main actor context, but still captures self
        processingTask = Task.detached(priority: .utility) { [weak self] in
            for data in dataBuffer {
                // Exit early if the task was cancelled via deinit or user action
                if Task.isCancelled { return }
                
                // Heavy computation off the main thread
                let processed = data.count * 42
                
                guard let self = self else { return }
                await self.saveResult(processed)
            }
        }
    }
    
    private func saveResult(_ count: Int) async {
        print("Saved result: \(count)")
    }
    
    deinit {
        // Ensure background processing halts immediately when this instance deallocates
        processingTask?.cancel()
    }
}

// Example caller
Task { @MainActor in
    let engine = HeavyProcessingEngine()
    engine.startBackgroundWork(dataBuffer: [Data("alpha".utf8), Data("beta".utf8)])
    try? await Task.sleep(nanoseconds: 250_000_000)
    engine.startBackgroundWork(dataBuffer: [])
}

/*:
 ## 3. Managing Multiple Unstructured Tasks
 
 You can collect multiple `Task` handles in an array or dictionary to batch-cancel them when a view or service shuts down.
 */
@MainActor
class BatchDownloadManager {
    private var activeTasks: [String: Task<Void, Never>] = [:]
    
    func downloadFile(id: String, url: String) {
        // Store task handle by ID
        activeTasks[id] = Task { [weak self] in
            // Perform async work
            do {
                try await Task.sleep(nanoseconds: 2_000_000_000)
            } catch is CancellationError {
                print("Download cancelled \(id)")
                return
            } catch {
                print("Failed to download file \(id): \(error)")
                return
            }
            
            print("Downloaded file \(id)")
            
            // Cleanup from active tasks dictionary after completion
            self?.activeTasks.removeValue(forKey: id)
        }
    }
    
    func cancelAll() {
        activeTasks.values.forEach { $0.cancel() }
        activeTasks.removeAll()
    }
    
    deinit {
        activeTasks.values.forEach { $0.cancel() }
    }
}

// Example caller
Task { @MainActor in
    let manager = BatchDownloadManager()
    manager.downloadFile(id: "report.pdf", url: "https://example.com/report.pdf")
    try? await Task.sleep(nanoseconds: 250_000_000)
    manager.cancelAll()
}
    
/*:
 
 ## 4. Automated Lifecycle via SwiftUI `.task`
 
 In SwiftUI, you rarely need manual task storage. The `.task` modifier creates an unstructured task tied to the View's lifetime and automatically cancels it when the View disappears from screen.
 */

import SwiftUI
import PlaygroundSupport
struct ProfileView: View {
    @State private var username = "Loading..."
    
    var body: some View {
        Text(username)
            .task {
                // Automatically starts when view appears
                // Automatically cancels when view disappears!
                if let name = try? await fetchName() {
                    username = name
                }
            }
    }
    
    func fetchName() async throws -> String {
        try await Task.sleep(nanoseconds: 5_000_000_000)
        return "Jane Doe"
    }
}

PlaygroundPage.current.setLiveView(ProfileView())
/*:
 ## 5. Task Collection Manager (AnyCancellable Equivalent)
 
 You can create a helper class that acts like Combine's `Set<AnyCancellable>` to automatically cancel all registered tasks when an object deinitializes.
 */

final class TaskBag {
    private var tasks: [Task<Void, Never>] = []
    
    func add(_ task: Task<Void, Never>) {
        tasks.append(task)
    }
    
    deinit {
        tasks.forEach { $0.cancel() }
    }
}

class DashboardViewModel {
    private let taskBag = TaskBag()
    
    func loadDashboard() {
        // Task handle is added to bag; auto-cancelled when ViewModel deallocates
        let task = Task {
            do {
                try await Task.sleep(nanoseconds: 2_000_000_000)
            } catch {
                print("Task Cancelled")
                return
            }
            print("Dashboard refreshed")
        }
        
        taskBag.add(task)
    }
}

Task { @MainActor in
    var viewModel: DashboardViewModel? = DashboardViewModel()
    viewModel?.loadDashboard()
    try? await Task.sleep(nanoseconds: 250_000_000)
    viewModel = nil
}

/*:
 ---
 ## 🧠 Mental Model
 
 Think of unstructured tasks as **Hired Contractors with Keycards**:
 * **Strong Capture (`self`)**: You give the contractor a permanent keycard to your house. Even if you want to close down the house (`deinit`), you can't lock up because the contractor is still inside holding open the door.
 * **Weak Capture (`[weak self]`)**: You give the contractor a temporary guest pass. They periodically check if the house is still open (`guard let self = self`). If the house shuts down while they are working, they stop work and leave quietly.
 * **Task Handle (`Task?`)**: A remote control walkie-talkie in your hand. Calling `.cancel()` is pressing the stop button to tell the contractor to wrap up immediately.
 * **SwiftUI `.task` (Dog Park Fence)**: You open the dog park gate when the view appears, and close it when the view disappears. The system guarantees no task strays outside the view's lifetime.
 * **TaskBag (Leash Bundle)**: You attach multiple dog leashes to a single hook on your belt. When you leave the park (`deinit`), pulling the hook automatically pulls back all dogs at once.
 */
//: [Next](@next)
