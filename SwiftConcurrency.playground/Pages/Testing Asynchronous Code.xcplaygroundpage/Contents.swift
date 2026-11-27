//: [Previous](@previous)
/*:
 # Lesson: Testing Asynchronous Code

 Reliable concurrency tests coordinate through results and explicit signals—not guesses about how long an operation will take. This lesson uses XCTest-style examples to test async functions, tasks, cancellation, and asynchronous streams deterministically.

 ## Key Concepts

 * **Await the result**: Async XCTest methods can directly await async functions and task values.
 * **Control dependencies**: Inject a test implementation or closure so the test decides what an operation returns or throws.
 * **Synchronize with events**: Use continuations, actors, or XCTest expectations to know when work reaches a point; avoid using sleeps as timing guesses.
 * **Finish the work under test**: Await tasks and finish streams so tests do not leave work running or hang.

 ---

 ## 1. Test Async Functions with Controlled Dependencies

 Test the result and failure behavior directly. Injecting the dependency makes the example independent of networks, clocks, and external services.
 */

enum ProfileServiceError: Error, Equatable {
    case unavailable
}

func loadDisplayName(
    using fetchName: @Sendable () async throws -> String
) async throws -> String {
    let name = try await fetchName()
    return name.uppercased()
}

/*:
 ## Runnable Playground Test Runner

 XCTest test methods are discovered only in an XCTest test target. The runner in `Sources/TestingAsynchronousCodeRunner.swift` executes the same async behaviors inside this page and provides pass/fail output.

 ---
 */

/*:
 In an XCTest target, an async test method can call the function with `try await`. Evaluate the result before passing it to an assertion: XCTest assertion arguments are autoclosures and cannot themselves suspend.

 ```swift
 func testLoadDisplayName() async throws {
     let name = try await loadDisplayName {
         "Avery"
     }

     XCTAssertEqual(name, "AVERY")
 }

 func testLoadDisplayNamePropagatesFailure() async {
     do {
         _ = try await loadDisplayName {
             throw ProfileServiceError.unavailable
         }
         XCTFail("Expected the fetch to fail")
     } catch ProfileServiceError.unavailable {
         // Expected failure.
     } catch {
         XCTFail("Unexpected error: \(error)")
     }
 }
 ```

 Keep each test focused on one outcome. A fixed return value or controlled error is more repeatable than a live service or a real delay.

 ---

 ## 2. Await Tasks Instead of Guessing When They Finish

 A task handle exposes its result through `value`. Awaiting it gives the test a clear completion point and propagates errors for throwing tasks.

 ```swift
 func testTaskReturnsItsValue() async throws {
     let task = Task {
         try await loadDisplayName { "Sam" }
     }

     let result = try await task.value
     XCTAssertEqual(result, "SAM")
 }
 ```

 Avoid asserting on shared state immediately after creating a task: the task may not have run yet. Prefer returning a value from the task and awaiting it. If the behavior under test specifically depends on overlap or an intermediate state, add an explicit synchronization signal for that state.

 ---

 ## 3. Test Cancellation with a Signal, Not a Timing Guess

 Cancellation is cooperative: `cancel()` requests cancellation, and the operation must observe it. This small actor lets a test wait until the operation has started before requesting cancellation.
 */

actor AsyncStartSignal {
    private var hasStarted = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func signalStarted() {
        hasStarted = true
        let pendingWaiters = waiters
        waiters.removeAll()
        pendingWaiters.forEach { $0.resume() }
    }

    func waitUntilStarted() async {
        guard !hasStarted else { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
}

func waitForCancellation(started: AsyncStartSignal) async throws {
    await started.signalStarted()
    try await Task.sleep(for: .seconds(60))
}

/*:
 The long sleep below is the cancellable operation, not a test delay. The signal establishes ordering: the test waits until the task reaches the operation, then cancels it. `Task.sleep` throws when its task is cancelled, including if cancellation arrived just before the sleep began.

 ```swift
 func testCancellationIsObserved() async {
     let started = AsyncStartSignal()
     let task = Task {
         try await waitForCancellation(started: started)
     }

     await started.waitUntilStarted()
     task.cancel()

     do {
         try await task.value
         XCTFail("Expected cancellation")
     } catch is CancellationError {
         // Expected: the operation cooperates with cancellation.
     } catch {
         XCTFail("Unexpected error: \(error)")
     }
 }
 ```

 For operations backed by a callback or resource, test the cancellation handler's cleanup too. Use a controllable test double to observe that cleanup occurred; do not rely only on checking `Task.isCancelled`.

 ---

 ## 4. Test Streams by Controlling Their Continuation

 A test can own an `AsyncStream` continuation, yield known values, and finish the stream. Its collector task returns only after iteration ends, giving the test a deterministic point to assert the complete sequence.

 ```swift
 func testStreamDeliversValuesInOrder() async {
     let (stream, continuation) = AsyncStream<Int>.makeStream()

     let collector = Task { () -> [Int] in
         var values: [Int] = []
         for await value in stream {
             values.append(value)
         }
         return values
     }

     continuation.yield(10)
     continuation.yield(20)
     continuation.finish()

     let values = await collector.value
     XCTAssertEqual(values, [10, 20])
 }
 ```

 The default stream uses an unbounded buffer, so these yields are not lost while the collector is scheduled. If production code uses a bounded buffering policy, test the documented drop behavior as well as the values that are delivered. Always finish a test-owned stream, and cancel or otherwise stop any producer task when a consumer terminates.

 ---

 ## Run These Behaviors in the Playground

 The runner below calls the lesson examples, awaits every task, and prints a pass or failure instead of relying on XCTest discovery.
 */

runAsync {
    await TestingAsynchronousCodeRunner.run("async function returns a transformed value") {
        let name = try await loadDisplayName { "Avery" }
        try TestingAsynchronousCodeRunner.checkEqual(name, "AVERY", "display name")
    }

    await TestingAsynchronousCodeRunner.run("async function propagates its error") {
        do {
            _ = try await loadDisplayName {
                throw ProfileServiceError.unavailable
            }
            throw TestingAsynchronousCodeRunner.TestError.assertionFailed(
                "expected ProfileServiceError.unavailable"
            )
        } catch ProfileServiceError.unavailable {
            // Expected error.
        }
    }

    await TestingAsynchronousCodeRunner.run("task returns its value") {
        let task = Task {
            try await loadDisplayName { "Sam" }
        }

        let result = try await task.value
        try TestingAsynchronousCodeRunner.checkEqual(result, "SAM", "task result")
    }

    await TestingAsynchronousCodeRunner.run("task cancellation is observed") {
        let started = AsyncStartSignal()
        let task = Task {
            try await waitForCancellation(started: started)
        }

        await started.waitUntilStarted()
        task.cancel()

        do {
            try await task.value
            throw TestingAsynchronousCodeRunner.TestError.assertionFailed(
                "expected Task.sleep to throw CancellationError"
            )
        } catch is CancellationError {
            // Expected cancellation.
        }
    }

    await TestingAsynchronousCodeRunner.run("stream yields values in order") {
        let (stream, continuation) = AsyncStream<Int>.makeStream()

        let collector = Task { () -> [Int] in
            var values: [Int] = []
            for await value in stream {
                values.append(value)
            }
            return values
        }

        continuation.yield(10)
        continuation.yield(20)
        continuation.finish()

        let values = await collector.value
        try TestingAsynchronousCodeRunner.checkEqual(values, [10, 20], "stream values")
    }
}

/*:
 ---

 ## 5. Practical Testing Guidance

 * **Do not use arbitrary sleeps to make a test “wait long enough.”** A sleep can make a test slow and still leave a race. Use a signal, a continuation-controlled dependency, or an expectation tied to the event being tested.
 * **Use XCTest expectations for callback-based APIs.** Fulfill an expectation from the callback and await it with XCTest's async fulfillment API. Give waits a reasonable timeout so a broken test fails instead of hanging indefinitely.
 * **Test observable behavior.** Check returned values, thrown errors, cancellation effects, yielded elements, and cleanup—not executor thread choices or assumptions about scheduling order.
 * **Keep ownership clear.** Await tasks created by a test, finish streams, and make teardown release any gates so a failed assertion does not strand work.

 ---
 ## 🧠 Mental Model

 Think of a deterministic concurrency test as a **stage-managed scene**: test doubles provide predictable inputs, signals cue each actor when to proceed, and awaiting the result marks the end of the scene. The test controls what it can control without assuming which thread runs next or how quickly the scheduler responds.
 */
//: [Next](@next)
