//: [Previous](@previous)
import SwiftUI

/*:
 # Lesson: `Sendable` and Strict Concurrency Checking

 Swift concurrency can move values and closures between tasks and actors. `Sendable` marks values that can safely cross those concurrency boundaries without introducing data races.

 ## Key Concepts

 * **`Sendable`**: A type-level guarantee that values can be transferred safely between concurrent contexts.
 * **`@Sendable` closures**: Closures that can cross concurrency boundaries and therefore have safe captures.
 * **Actors**: Reference types that protect mutable state through actor isolation and are implicitly `Sendable`.
 * **Strict concurrency checking**: Compiler checks that find unsafe transfers and captures. Swift 6 language mode enforces these checks as errors.

 ---

 ## 1. Sendable Value Types

 Structs and enums whose stored values and associated values are all `Sendable` can conform to `Sendable`. Value semantics make these types straightforward to transfer between tasks.
 */

struct UserProfile: Sendable {
    let id: Int
    let displayName: String
}

enum RequestState: Sendable {
    case waiting
    case completed(byteCount: Int)
    case failed(message: String)
}

let profile = UserProfile(id: 42, displayName: "Taylor")
let state = RequestState.completed(byteCount: 1_024)

let summaryTask = Task.detached {
    "\(profile.displayName) has a \(state)"
}

Task {
    print(await summaryTask.value)
}

/*:
 `Task.detached` does not inherit the caller's actor context. Its closure is `@Sendable`, so values it captures must be safe to use concurrently.

 ---

 ## 2. Sendable Reference Types

 A class can conform to `Sendable` when it is `final`, has only immutable stored properties, and those properties are themselves `Sendable`.
 */

final class DisplayPreferences: Sendable {
    let colorScheme: String
    let textScale: Double

    init(colorScheme: String, textScale: Double) {
        self.colorScheme = colorScheme
        self.textScale = textScale
    }
}

let preferences = DisplayPreferences(colorScheme: "dark", textScale: 1.0)
let preferenceTask = Task.detached {
    "Using \(preferences.colorScheme) mode at \(preferences.textScale)x scale"
}

Task {
    print(await preferenceTask.value)
}

/*:
 A mutable class is not safe to share just because it is passed through a constant reference. Its state could be accessed and changed concurrently.

 ```swift
 final class UnsafeCounter {
     var value = 0
 }

 let counter = UnsafeCounter()
 let task = Task.detached {
     counter.value += 1
 }
 ```

 In Swift 6 mode, capturing `counter` in the detached task is rejected because the mutable class is not `Sendable`. Prefer an actor for shared mutable state rather than adding a conformance that merely hides the race.

 ---

 ## 3. Actors Protect Shared Mutable State

 Actors are reference types with isolated mutable state. They are implicitly `Sendable`; callers use `await` when accessing actor-isolated methods from outside the actor.
 */

actor MessageStore {
    private var messages: [String] = []

    func append(_ message: String) {
        messages.append(message)
    }

    func messageCount() -> Int {
        messages.count
    }
}

let messageStore = MessageStore()

Task {
    await messageStore.append("Hello from a task")
    print("Stored messages: \(await messageStore.messageCount())")
}

/*:
 ---

 ## 4. `@Sendable` Closures

 An `@Sendable` function type states that the closure may be transferred to another concurrency domain. Captured values must be safe to transfer, and captured mutable local variables cannot be modified by the closure.
 */

func makeGreeting(for name: String) -> @Sendable () -> String {
    {
        "Hello, \(name)!"
    }
}

let greeting = makeGreeting(for: "Sam")
print(greeting())

/*:
 This closure captures an immutable `String`, which is `Sendable`. By contrast, the following capture would be rejected under strict concurrency checking:

 ```swift
 var count = 0
 let increment = { @Sendable in
     count += 1
 }
 ```

 Use an actor or another correctly synchronized type when concurrent code needs to mutate shared state.

 ---

 ## 5. A Sendable Service Protocol in a ViewModel's Unstructured Task

 A ViewModel can start asynchronous work from a synchronous UI action with `Task { }`. It depends on a `Sendable` service protocol rather than a concrete implementation, making the service easy to replace in tests or with another implementation. This stateless service is a `final` class: it has no mutable state that needs actor isolation. The `UserProfile` is `Sendable`, so it can safely be returned to the main actor, where the ViewModel publishes it. `Task { }` inherits the ViewModel's `@MainActor` context; it is unstructured, but is not detached.
 */

protocol ProfileServicing: Sendable {
    func fetchProfile() async throws -> UserProfile
}

final class ProfileService: ProfileServicing {
    func fetchProfile() async throws -> UserProfile {
        try await Task.sleep(nanoseconds: 500_000_000)
        return UserProfile(id: 7, displayName: "Jordan")
    }
}

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var profile: UserProfile?
    private var loadTask: Task<Void, Never>?
    private let service: any ProfileServicing

    init(service: any ProfileServicing = ProfileService()) {
        self.service = service
    }

    func loadProfile() {
        loadTask?.cancel()
        loadTask = Task {
            do {
                let loadedProfile = try await service.fetchProfile()
                guard !Task.isCancelled else { return }

                profile = loadedProfile
            } catch is CancellationError {
                print("Profile load cancelled")
            } catch {
                print("Profile load failed: \(error)")
            }
        }
    }

    func cancelLoading() {
        loadTask?.cancel()
        loadTask = nil
    }
}

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()

    var body: some View {
        VStack(spacing: 12) {
            Button("Load profile") {
                viewModel.loadProfile()
            }

            if let profile = viewModel.profile {
                Text(profile.displayName)
            }
        }
        .onDisappear {
            viewModel.cancelLoading()
        }
    }
}

/*:
 `UserProfile: Sendable` is the value transferred across the actor boundary. The `@MainActor` ViewModel is also safe to pass between concurrency domains because global-actor-isolated types are implicitly `Sendable`. The task handle lets the ViewModel cancel its unstructured task; it does not make that task a child or automatically tie its lifetime to a view.

 ---

 ## 6. Understanding Compiler Diagnostics

 Common diagnostics point to one of these issues:

 * **A non-Sendable value crosses an isolation boundary**: Pass a `Sendable` value, keep the operation isolated to its actor, or redesign ownership so the value is not shared.
 * **An `@Sendable` closure captures mutable state**: Avoid the capture or move the state behind an actor or synchronization primitive.
 * **A type claims `Sendable` but contains unsafe shared state**: Make the type safe by design. `@unchecked Sendable` disables compiler verification and is appropriate only when the type itself enforces synchronization and the conformance is carefully audited.
 * **Actor-isolated data is accessed without `await`**: Call the isolated operation asynchronously from outside its actor.

 Swift 6 language mode performs complete data-race safety checks. In Swift 5 language mode, enable **Complete** strict concurrency checking to surface these diagnostics before migrating.

 ---

 ## 🧠 Mental Model

 Think of sending work between tasks as **making a delivery**:
 * **`Sendable` values (Safe-to-ship parcels)**: A value can cross to another task when its contents are safe to use there too.
 * **`@Sendable` closures (Delivery instructions)**: The closure may be sent to another task, so anything it carries along in its captures must also be safe to transfer.
 * **Actors (Staffed depots)**: You can send an actor's address to other tasks, but its mutable state stays at the depot and is accessed through the actor.
 * **Compiler diagnostics (Shipment checks)**: A warning means the compiler cannot verify that the delivery is safe. Fix the ownership or isolation issue instead of just bypassing the check.
 */
//: [Next](@next)
