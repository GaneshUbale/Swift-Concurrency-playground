//: [Previous](@previous)
/*:
 # Lesson: `withCheckedContinuation` and `withCheckedThrowingContinuation`

 Continuations let you wrap callback-based or closure-based APIs as Swift Concurrency async functions.

 ## Key Concepts

 * **Continuation**: A resumable handle for returning an async result later.
 * **`withCheckedContinuation`**: Use for APIs that cannot throw.
 * **`withCheckedThrowingContinuation`**: Use for APIs that can succeed or fail.
 * **Exactly Once**: Resume a continuation exactly once, either normally or with an error.
 * **Checked APIs**: Debugging versions of continuations that report missing or duplicate resumes.

 ---

 ## 1. Wrapping a Callback API

 Start with an existing callback API that returns a `String` asynchronously:
 */

import Foundation

func fetchStatus(completion: @escaping (String) -> Void) {
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

func fetchProfile(completion: @escaping (Result<Profile, ProfileError>) -> Void) {
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

 `Result.get()` provides a concise way to bridge the two outcomes:
 */

func fetchProfileWithResult() async throws -> Profile {
    try await withCheckedThrowingContinuation { continuation in
        fetchProfile { result in
            continuation.resume(with: result)
        }
    }
}

/*:
 ---
 ## 🧠 Mental Model

 Think of a checked continuation as a **claim ticket**:
 * **Non-throwing continuation**: The callback returns a result and hands over the ticket.
 * **Throwing continuation**: The callback either fulfills the ticket or reports an error.
 * **Exactly once**: The ticket can be claimed only once. Resuming twice or never resuming leaves the async operation incorrect or suspended.

 Prefer native async APIs when available. Use continuations mainly to bridge legacy callbacks or third-party APIs.
 */
//: [Next](@next)
