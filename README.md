# Swift Concurrency Playground

This project is a hands-on learning playground for exploring Swift concurrency end-to-end. It is designed for developers who want to understand how async/await, tasks, task groups, cancellation, priorities, and error handling work in real Swift code.

Instead of reading only theory, you can open this playground and run examples directly to see behavior in action.

## What this project is for

This repository is meant to help users:

- understand the basics of `async` and `await`
- learn how `Task` works in Swift
- explore structured and unstructured concurrency
- handle errors and cancellations safely
- build task groups for batch work
- limit concurrent work to avoid overload
- understand priorities, delays, and task lifetime management
- apply concurrency ideas in SwiftUI and real-world apps

## Learning approach

The project is organized as a step-by-step journey. Each page focuses on a specific concurrency concept, starting from the fundamentals and moving toward more advanced patterns.

## Playground structure

The project contains a collection of interactive pages under `Pages/`, each representing a lesson or example.

Follow the lessons in this order, from fundamentals to more advanced topics:

1. `Introduction to async,await Syntax`
2. `Task yield vs Task sleep`
3. `Task Cancellation`
4. `Error Handling in Tasks`
5. `Structured vs. Unstructured Tasks`
6. `Task Groups`
7. `Discarding Task Groups`
8. `Resuming Work withThrowingDiscardingTaskGroup`
9. `Task Timeout Handler Using Task Groups`
10. `Limiting Concurrent Tasks in a Task Group`
11. `Limiting Concurrent Tasks in a Task Group Handeled Error`
12. `Managing Task Priorities`
13. `Task Local Storage`
14. `Manual Lifetime Management of Unstructured Tasks`
15. `Detached Tasks`
16. `Running Tasks in SwiftUI`
17. `Actors and Actor Isolation`
18. `Sendable`
19. `Async Streams`
20. `AsyncSequence Operations`
21. `Using Immediate Tasks`

## Why this project matters

Swift concurrency is one of the most important parts of modern app development. Without a clear understanding of concurrency, apps can suffer from:

- race conditions
- resource exhaustion
- missed cancellation behavior
- unhandled async errors
- poor UI responsiveness

This project helps developers build intuition by showing the same ideas in small, focused examples that are easy to experiment with.

## How to use this project

1. Open the playground in Xcode.
2. Start from the index page to browse all lessons.
3. Run each page individually.
4. Read the example, change values, and observe how concurrency behavior changes.
5. Use the code as a reference when implementing async features in your own apps.

## Typical learning flow

The lesson sequence starts with async/await fundamentals, then introduces task scheduling, cancellation, errors, and structured concurrency. It builds toward task groups and bounded concurrency before covering priorities, task-local values, unstructured task lifetimes, and SwiftUI. Actors and `Sendable` introduce data safety, followed by asynchronous sequences and the specialized immediate-task APIs.

## Example theme

One of the key advanced topics in this project is limiting concurrency inside a task group. This pattern is especially useful when processing large sets of items without overwhelming memory or external services.

The playground demonstrates a bounded-concurrency pattern where only a limited number of tasks are allowed to run at the same time while preserving batch progress and collecting individual results cleanly.

## Project files

- `Pages/` – all lesson pages and runnable examples
- `Index.xcplaygroundpage` – project table of contents
- `contents.xcplayground` – playground configuration
- `playground.xcworkspace` – Xcode workspace metadata

## Notes

This is an educational project intended for exploration and experimentation. It is best used as a practical reference for learning Swift concurrency patterns in a visual, interactive format.

If you are learning Swift concurrency for the first time, this project is a good way to move from beginner concepts to more advanced patterns with real examples.

## Swift Concurrency Interview Questions

- [Swift Concurrency Interview Questions That Reveal Real Experience by RAHUL NIMJE](https://medium.com/@rahulnimje94/swift-concurrency-interview-questions-that-reveal-real-experience-572d6fddb223)

## Behind the Scenes of Swift Concurrency

- [Behind the Scenes of Async Functions by Vitaly Batrakov](https://vbat.dev/behind-the-scenes-of-async-functions)
