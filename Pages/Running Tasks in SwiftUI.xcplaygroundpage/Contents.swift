//: [Previous](@previous)
/*:
 # Lesson: Running Tasks in SwiftUI
 
 SwiftUI provides dedicated view modifiers and state-driven abstractions to manage asynchronous tasks seamlessly alongside the view lifecycle.
 
 ## Key Concepts
 
 * **`.task` Modifier**: Launches an asynchronous task when a view appears and automatically cancels it when the view disappears.
 * **`id` Parameter**: Reruns the task whenever an observed identity or state value changes.
 * **`refreshable` Modifier**: Enables pull-to-refresh behavior by attaching an asynchronous task to a scrollable container.
 
 ---
 
 ## 1. Basic Task Execution with `.task`
 
 The `.task` modifier attaches an asynchronous task to the view. Execution starts when the view appears on screen.
 */

import SwiftUI
import PlaygroundSupport

struct UserProfileView: View {
    @State private var username = "Loading..."
    
    var body: some View {
        Text(username)
            .padding()
            .task {
                // Starts automatically when the view appears on screen
                if let fetchedName = try? await fetchProfileName() {
                    username = fetchedName
                }
            }
    }
    
    func fetchProfileName() async throws -> String {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return "Jane Doe"
    }
}

//PlaygroundPage.current.setLiveView(UserProfileView())

/*:
 ## 2. Restarting Tasks with `.task(id:)`
 
 Pass an observable value to the `id` parameter. When the value changes, SwiftUI automatically cancels the running task and launches a new one with the updated value.
 */


struct SearchResultsView: View {
    @State var searchQuery: String
    @State private var results: [String] = []
    
    var body: some View {
        NavigationStack {
            TextField("Search",text: $searchQuery)
                .textFieldStyle(.roundedBorder)
            List(results, id: \.self) { item in
                Text(item)
            }
            .navigationTitle("List with search")
            // Cancels any ongoing search and restarts whenever `searchQuery` changes
            .task(id: searchQuery) {
                guard !searchQuery.isEmpty else { return }
                results = await performSearch(query: searchQuery)
            }
        }
    }
    
    func performSearch(query: String) async -> [String] {
        do {
            try await Task.sleep(for: .seconds(1))
        } catch {
            return []
        }
        
        return ["Result 1 for \(query)", "Result 2 for \(query)"]
    }
}
PlaygroundPage.current.setLiveView(SearchResultsView(searchQuery: "A"))
/*:
 ## 3. Supporting Pull-to-Refresh with `.refreshable`
 
 The `.refreshable` modifier integrates an async closure into lists and scroll views, keeping the UI refresh indicator active until the task completes.
 */

struct FeedView: View {
    @State private var items = ["Item A", "Item B"]
    
    var body: some View {
        NavigationStack {
            List(items, id: \.self) { item in
                Text(item)
            }
            .navigationTitle("Feed")
            .refreshable {
                // Triggered when the user pulls down to refresh
                await reloadFeed()
            }
        }
    }
    
    func reloadFeed() async {
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        items.append("Item \(items.count + 1)")
    }
}

//PlaygroundPage.current.setLiveView(FeedView())

/*:
 ---
 ## 🧠 Mental Model
 
 Think of SwiftUI tasks as **Automatic Room Lights**:
 * **`.task` (Motion Sensor)**: Turns on the light (`Task`) as soon as someone enters the room (`view appears`), and automatically shuts off the light (`task.cancel()`) when everyone leaves the room (`view disappears`).
 * **`.task(id:)` (Dimmer Knob)**: Whenever you turn the dial (`id` updates), the light resets immediately to match the new setting.
 * **`.refreshable` (Manual Pull Switch)**: Pulling down on the cord starts a timed light sequence that turns off automatically once the work is complete.
 */
