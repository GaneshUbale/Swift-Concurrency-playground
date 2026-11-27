//: [Previous](@previous)
/*:
 # Lesson: `withCheckedContinuation` and `withCheckedThrowingContinuation`

 Continuations let you adapt older callback-based APIs—including delegate callbacks—to Swift Concurrency. The caller can then `await` the result instead of coordinating callbacks.

 ## Key Concepts

 * **Continuation**: A resumable handle for returning an async result later.
 * **`withCheckedContinuation`**: Use for APIs that cannot throw.
 * **`withCheckedThrowingContinuation`**: Use for APIs that can succeed or fail.
 * **Exactly Once**: Every continuation must be resumed exactly once, either normally or with an error.
 * **Checked APIs**: A checked continuation warns if it is abandoned without being resumed and traps if resumed more than once.
 * **Cancellation**: A continuation does not automatically resume when its task is cancelled. A bridge must handle cancellation explicitly if the underlying operation supports it.

 ---

 ## 1. Wrapping a Callback API

 Start with an existing callback API that returns a `String` asynchronously:
 */

import Foundation
import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true

func fetchStatus(completion: @escaping @Sendable (String) -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        completion("Ready")
    }
}

/*:
 Convert it to an async function with `withCheckedContinuation`:
 */

func fetchStatusAsync() async -> String {
    await withCheckedContinuation { continuation in
        fetchStatus { status in
            continuation.resume(returning: status)
        }
    }
}

Task {
    print("Started:")
    let status = await fetchStatusAsync()
    print("Status: \(status)")
}

/*:
 ## 2. Wrapping a Failing Callback

 For a callback API that may fail, use `withCheckedThrowingContinuation`:
 */

enum ProfileError: Error {
    case unavailable
}

struct Profile {
    let name: String
}

func fetchProfile(completion: @escaping @Sendable (Result<Profile, ProfileError>) -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        completion(.success(Profile(name: "Ganesh")))
    }
}

func fetchProfileAsync() async throws -> Profile {
    try await withCheckedThrowingContinuation { continuation in
        fetchProfile { result in
            switch result {
            case .success(let profile):
                continuation.resume(returning: profile)
            case .failure(let error):
                continuation.resume(throwing: error)
            }
        }
    }
}

Task {
    do {
        let profile = try await fetchProfileAsync()
        print("Profile: \(profile.name)")
    } catch {
        print("Could not fetch profile: \(error)")
    }
}

/*:
 ## 3. Using a Result Directly

 `Result` callbacks can be forwarded directly with `resume(with:)`:
 */

func fetchProfileWithResult() async throws -> Profile {
    try await withCheckedThrowingContinuation { continuation in
        fetchProfile { result in
            continuation.resume(with: result)
        }
    }
}

/*:
 ## 4. Adapting a Legacy Delegate

 Delegate APIs often report completion through a protocol method instead of a completion closure. Store the continuation while the operation is in flight, then resume it from the delegate callback.
 */

enum LookupError: Error {
    case unavailable
}

@MainActor
protocol LegacyLookupDelegate: AnyObject {
    func lookupDidFinish(_ result: Result<String, LookupError>)
}

@MainActor
final class LegacyLookupService {
    weak var delegate: (any LegacyLookupDelegate)?

    func startLookup() {
        // Simulates a legacy API that calls its delegate after the work completes.
        Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(300))
                self?.delegate?.lookupDidFinish(.success("Found through the delegate"))
            } catch {
                self?.delegate?.lookupDidFinish(.failure(.unavailable))
            }
        }
    }
}

@MainActor
final class LookupAdapter: LegacyLookupDelegate {
    private let service = LegacyLookupService()
    private var continuation: CheckedContinuation<String, Error>?

    init() {
        service.delegate = self
    }

    func lookup() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            service.startLookup()
        }
    }

    func lookupDidFinish(_ result: Result<String, LookupError>) {
        guard let continuation else {
            assertionFailure("Delegate called without a pending lookup")
            return
        }

        self.continuation = nil
        continuation.resume(with: result)
    }
}

Task { @MainActor in
    do {
        let value = try await LookupAdapter().lookup()
        print(value)
    } catch {
        print("Lookup failed: \(error)")
    }
}

/*:
 The adapter keeps the continuation until the delegate reports success or failure. Production bridges should also define what happens if the operation is cancelled, times out, or can produce multiple delegate events; each waiting continuation still needs exactly one resume.

 ## 5. Awaiting a Notification

 For notifications, prefer `NotificationCenter`'s async sequence API when it is available. It already adapts notification delivery to `async` iteration, so a checked continuation is not needed:
 */

extension Notification.Name {
    static let lessonDidFinish = Notification.Name("lessonDidFinish")
}

func waitForLessonNotification() async throws -> Notification {
    for await notification in NotificationCenter.default.notifications(named: .lessonDidFinish) {
        return notification
    }

    throw CancellationError()
}

Task {
    do {
        let notification = try await waitForLessonNotification()
        print("Received notification: \(notification.name)")
    } catch {
        print("Notification wait ended: \(error)")
    }
}

// A legacy notification sender posts the event after the async wait has started:
func postLessonFinishedNotification() {
    NotificationCenter.default.post(name: .lessonDidFinish, object: nil)
}
Task {
    try! await Task.sleep(for: .seconds(2))
    postLessonFinishedNotification()
    
    PlaygroundPage.current.needsIndefiniteExecution = false
}
 
/*:
 If you must bridge an older one-shot observer API, use a checked continuation in its observer callback and remove the observer when it fires. Also make sure cancellation removes the observer and resumes the continuation exactly once. Do not leave a block observer registered after the async wait has completed.

 ---
 ## 🧠 Mental Model

 Think of a checked continuation as a **claim ticket**:
 * **Non-throwing continuation**: The callback returns a result and hands over the ticket.
 * **Throwing continuation**: The callback either fulfills the ticket or reports an error.
 * **Exactly once**: The ticket can be claimed only once. Resuming twice traps; never resuming leaves the async operation suspended.

 Prefer native async APIs when available. Use continuations mainly to bridge legacy callbacks, delegates, or third-party APIs.
 */
//: [Next](@next)
