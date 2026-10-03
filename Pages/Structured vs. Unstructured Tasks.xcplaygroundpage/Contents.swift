//: [Previous](@previous)
/*:
 # Lesson: Structured vs. Unstructured Tasks
 
 Swift Concurrency organizes work into two main execution models: **Structured Concurrency** and **Unstructured Concurrency**. Understanding when and how to bridge between them is essential for writing clean, leak-free asynchronous code.
 
 ## Key Concepts
 
 * **Structured Tasks**: Child tasks created within a explicit parent context (e.g., `async let`, `withTaskGroup`). They form a strict task hierarchy, inheriting lifetime, priority, cancellation, and actor context from the parent.
 * **Unstructured Tasks**: Created using `Task { }` or `Task.detached { }`. They do not have a parent task controlling their lifetime, meaning they outlive the scope where they were created unless explicitly managed.
 * **Bridging**: Unstructured tasks are primary entry points when calling asynchronous code from synchronous code (such as UI buttons or `viewDidLoad`).
 
 ---
 
 ## 1. Structured Concurrency Hierarchy
 
 In structured concurrency, parent tasks automatically wait for all child tasks to complete before exiting. Canceling a parent task automatically cancels all children.
 */

func fetchProfileData() async throws -> (String, Int) {
    // Both child tasks run concurrently within a structured scope
    async let username = "Alice"
    async let followerCount = 42
    
    // Execution waits here for both child tasks to finish
    return try await (username, followerCount)
}

Task {
    do {
        let profile = try await fetchProfileData()
        print("Structured fetch result: \(profile)")
    } catch {
        print("Structured fetch failed: \(error)")
    }
}

/*:
 ## 2. Unstructured Tasks (`Task { }`)
 
 `Task { }` creates an unstructured task. It inherits priority and local values from the current scope (and actor context, such as `@MainActor`), but **its lifetime is not tied to the outer scope**.
 */

class ViewManager {
    func buttonTapped() {
        // Calling async code from a synchronous function
        Task {
            // Inherits current actor context, but outlives buttonTapped()
            let data = try? await fetchProfileData()
            print("Fetched profile: \(String(describing: data))")
        }
        // buttonTapped() finishes immediately without waiting for the task above
    }
}

let viewManager = ViewManager()
viewManager.buttonTapped()

/*:
 ## 3. Manual Lifetime Management
 
 Because unstructured tasks don't automatically cancel when their enclosing scope exits, you must manually hold onto their handle and call `.cancel()` if you need to stop them.
 
 If the user leaves the screen before the work is done, the task will keep running unless you cancel it in `viewDidDisappear`, `deinit`, or a similar lifecycle callback.
 */

class SearchViewController {
    private var searchTask: Task<Void, Never>?
    
    deinit {
        screenDisappeared()
    }
    
    func userTyped(query: String) {
        // Cancel previous search in flight
        searchTask?.cancel()
        
        // Start a new unstructured task
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if !Task.isCancelled {
                print("Searching for: \(query)")
            }
        }
    }
    
    func screenDisappeared() {
        // Important: when the screen is left, cancel the task
        searchTask?.cancel()
        print("Screen disappeared: cancelled active search task")
    }
}

var searchController:SearchViewController? = SearchViewController()
Task {
    searchController?.userTyped(query: "swift concurrency") //---
    try? await Task.sleep(nanoseconds: 400_000_000)         //----
    searchController?.userTyped(query: "swift concurrency1")      //---
    try? await Task.sleep(nanoseconds: 200_000_000)               //--
    searchController?.userTyped(query: "swift concurrency2")          //---
    try? await Task.sleep(nanoseconds: 400_000_000)                   //----
    searchController?.userTyped(query: "swift concurrency3")                //---
    searchController = nil                                                  //
//    searchController?.screenDisappeared()

}

// It will print as below
//Searching for: swift concurrency
//Searching for: swift concurrency2
//Screen disappeared: cancelled active search task

/*:
 ## 4. SwiftUI Example: Cancel When the View Disappears
 
 In SwiftUI, a view often creates a `Task` in response to user input. If the user navigates away, the task continues unless you cancel it manually in `onDisappear` or use the `task(id:)` modifier, which automatically cancels and restarts when the view or identifier changes.
 */

import SwiftUI
import PlaygroundSupport

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    private var searchTask: Task<Void, Never>?
    
    func searchChanged(to text: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if !Task.isCancelled {
                print("SwiftUI search: \(text)")
            }else {
                print("canceled: \(text)")
            }
        }
    }
    
    func searchChanged1(to text: String) async {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if !Task.isCancelled {
                print("SwiftUI search: \(text)")
            }else {
                print("canceled: \(text)")
            }
    }
    
    func onDisappear() {
        searchTask?.cancel()
        print("SwiftUI screen disappeared: task cancelled")
    }
}

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    
    var body: some View {
        VStack {
            Text("Search")
                .font(.headline)
            TextField("Search", text: $viewModel.query)
                .textFieldStyle(.roundedBorder)
                .padding()
//                .onChange(of: viewModel.query) { newValue in
//                    viewModel.searchChanged(to: newValue)
//                }
                .task(id: viewModel.query, {
                    await viewModel.searchChanged1(to: viewModel.query)
                })
                .onDisappear {
                    viewModel.onDisappear()
                }
        }
        .padding()
    }
}

struct SearchDemoView: View {
    @State private var showSearch = true
    
    var body: some View {
        VStack(spacing: 20) {
            if showSearch {
                SearchView()
            } else {
                VStack {
                    Text("Search screen removed")
                        .font(.title2)
                    Text("onDisappear should have fired")
                        .foregroundStyle(.secondary)
                }
            }
            
            Button(showSearch ? "Hide Search Screen" : "Show Search Screen") {
                showSearch.toggle()
                print("Demo: button tapped, showSearch = \(showSearch)")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

PlaygroundPage.current.liveView = UIHostingController(rootView: SearchDemoView())

/*:
 ---
 ## 🧠 Mental Model
 
 Think of the difference as **Company Hierarchy vs. Independent Contractors**:
 * **Structured Tasks (Company Employees)**: A manager assigns tasks to team members within a project. The manager cannot submit the overall project until every employee turns in their work. If the manager's project gets canceled, all assigned employees are ordered to stop working immediately.
 * **Unstructured Tasks (Freelance Contractors)**: You hire a freelancer (`Task { }`) to do a side job. You don't have to stay at your desk while they work, and leaving the room doesn't stop them. If you want them to stop, you have to explicitly call them up and say "Cancel the order" (`task.cancel()`).
 */
//: [Next](@next)
