//: [Previous](@previous)
import Foundation

/*:
 # Lesson: `AsyncSequence` Operations

 `AsyncSequence` gives Swift a familiar sequence model for values that arrive over time. Instead of pulling values synchronously, consumers can iterate with `for await` while the producer yields values asynchronously.

 ## Key Concepts

 * **`AsyncSequence`**: A sequence whose elements are produced asynchronously.
 * **`map`**: transforms each value into a new result as it arrives.
 * **`filter`**: keeps only values that match a condition.
 * **`reduce`**: combines all values into a single result.
 * **Composing sequences**: chain multiple operators to build a pipeline of async work.

 ---

 ## 1. `map` transforms each value

 A mapped async sequence runs the transform for each emitted element. The output is produced in order, just like a synchronous sequence pipeline.
 */

func makeNumberStream() -> AsyncStream<Int> {
    AsyncStream { continuation in
        for number in 1...5 {
            continuation.yield(number)
        }
        continuation.finish()
    }
}

Task {
    let doubled = makeNumberStream().map { value in
        try? await Task.sleep(for: .milliseconds(100))
        return value * 2
    }

    for await value in doubled {
        print("Doubled: \(value)")
    }
}

/*:
 ---

 ## 2. `filter` keeps only selected values

 `filter` lets you ignore elements that do not meet a condition. The final stream contains only the values that pass.
 */

Task {
    let evens = makeNumberStream().filter { value in
        value % 2 == 0
    }

    for await value in evens {
        print("Even: \(value)")
    }
}

/*:
 ---

 ## 3. `reduce` combines the whole sequence

 `reduce` is useful when you want a single result after processing all values. It is especially helpful for totals, counts, summaries, and aggregates.
 */

Task {
    let total = await makeNumberStream().reduce(0) { @Sendable partialResult, value in
        try? await Task.sleep(for: .milliseconds(50))
        return partialResult + value
    }

    print("Total: \(total)")
}

/*:
 `reduce` is a strong fit for async work that needs to accumulate results while preserving the sequence’s natural order.

 ---

 ## 4. Composing async sequence operators

 You can combine transformations in one pipeline. This keeps complex async processing declarative and readable.
 */

Task {
    let summary = makeNumberStream()
        .map { value in
            try? await Task.sleep(for: .milliseconds(60))
            return value * 10
        }
        .filter { value in
            value >= 30
        }

    for await value in summary {
        print("Summary value: \(value)")
    }
}

/*:
 ---

 ## 5. When to use async sequence operators

 Use `map`, `filter`, and `reduce` when:

 * you receive values over time
 * you need to transform each item without blocking
 * you want to keep only relevant values
 * you need a final aggregated result

 These operators align with the same mental model as synchronous sequences, but they work naturally with asynchronous data sources.

 ---

 ## 🧠 Mental Model

 Think of an async sequence as a stream of work arriving over time. Operators like `map`, `filter`, and `reduce` are plain declarative steps that build a pipeline around that stream:

 * `map` changes each value.
 * `filter` decides which values continue.
 * `reduce` folds the stream into one result.
 * Chaining them keeps code readable and helps you reason about the data flow.
 */
//: [Next](@next)
