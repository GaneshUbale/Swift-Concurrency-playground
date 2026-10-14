//: [Previous](@previous)
/*:
 # Lesson: Async Streams

 An **async stream** lets asynchronous code produce a sequence of values over time. Consumers read those values with `for await`, just like other `AsyncSequence` values. Streams are useful for adapting callback-based APIs, notifications, and ongoing event sources to Swift Concurrency.

 ## Key Concepts

 * **`AsyncSequence`**: A sequence whose elements arrive asynchronously and are consumed with `for await`.
 * **`AsyncStream`**: A way to create a non-throwing asynchronous sequence and yield values through a continuation.
 * **`AsyncThrowingStream`**: The throwing counterpart, which can finish normally or end with an error.
 * **Finishing and cancellation**: Call `finish()` when no more values will arrive, and use `onTermination` to clean up a producer when iteration ends.

 ---

 ## 1. Creating and Consuming an `AsyncStream`

 A continuation can yield values and then finish the stream. Once finished, the loop exits after consuming the buffered values.
 */

func makeTemperatureStream() -> AsyncStream<Double> {
    AsyncStream { continuation in
        continuation.yield(21.5)
        continuation.yield(22.0)
        continuation.yield(21.8)
        continuation.finish()
    }
}

Task {
    for await temperature in makeTemperatureStream() {
        print("Temperature: \(temperature)°C")
    }
    print("Temperature stream finished")
}

/*:
 ## 2. Producing Values Asynchronously

 A producer task can yield values as work completes. Install `onTermination` to stop that task if the stream is no longer being consumed.
 */

func makeCountdownStream() -> AsyncStream<Int> {
    AsyncStream { continuation in
        let producer = Task {
            for count in stride(from: 3, through: 1, by: -1) {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                continuation.yield(count)
            }
            continuation.finish()
        }

        continuation.onTermination = { @Sendable _ in
            producer.cancel()
        }
    }
}

Task {
    for await count in makeCountdownStream() {
        print("Countdown: \(count)")
    }
    print("Countdown complete")
}

/*:
 ## 3. Handling Errors with `AsyncThrowingStream`

 Use `finish(throwing:)` when the producer fails. The consumer handles the error with `do`/`catch` around `for try await`.
 */

enum SensorError: Error {
    case disconnected
}

func makeSensorStream() -> AsyncThrowingStream<Int, Error> {
    AsyncThrowingStream { continuation in
        continuation.yield(24)
        continuation.yield(25)
        continuation.finish(throwing: SensorError.disconnected)
    }
}

Task {
    do {
        for try await reading in makeSensorStream() {
            print("Sensor reading: \(reading)")
        }
    } catch SensorError.disconnected {
        print("Sensor disconnected")
    } catch {
        print("Sensor stream failed: \(error)")
    }
}

/*:
 ## 4. Choosing a Buffering Policy

 By default, a stream buffers values until its iterator consumes them. For fast event sources, an unbounded buffer can grow unnecessarily. A bounded policy can keep only the newest value or the oldest pending values:

 * `.bufferingNewest(1)` is useful when only the latest state matters, such as a changing location.
 * `.bufferingOldest(10)` keeps up to ten pending events; newer values can be dropped when the buffer is full.

 `yield(_:)` reports whether a value was enqueued, dropped, or the stream had already finished. Check that result when dropping values would affect correctness.

 This example queues three values before the consumer starts. With a capacity of one, the stream retains only the newest value:
 */

let latestValueStream = AsyncStream<Int>(bufferingPolicy: .bufferingNewest(1)) { continuation in
    for value in [10, 20, 30] {
        switch continuation.yield(value) {
        case .enqueued(let remaining):
            print("Enqueued \(value); buffer capacity remaining: \(remaining)")
        case .dropped(let droppedValue):
            print("Dropped \(droppedValue)")
        case .terminated:
            print("Stream already terminated")
        @unknown default:
            print("Unexpected yield result")
        }
    }
    continuation.finish()
}

Task {
    for await value in latestValueStream {
        print("Consumed latest value: \(value)")
    }
}

/*:
 ---
 ## 🧠 Mental Model

 Think of an **async stream as a mailbox with an iterator**:
 * **`yield(_:)`** puts a new value into the mailbox.
 * **`for await`** waits for each value and processes it when it arrives.
 * **`finish()`** closes the mailbox after any buffered values are read.
 * **`onTermination`** lets the producer clean up when the consumer stops listening.
 * **Buffering policies** decide what happens when values arrive faster than the consumer can process them.
 */
//: [Next](@next)
