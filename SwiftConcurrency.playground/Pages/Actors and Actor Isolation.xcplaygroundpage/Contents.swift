//: [Previous](@previous)
import Foundation

/*:
 # Lesson: `Actors and Actor Isolation`

 Shared mutable state is one of the easiest ways to create data races in concurrent code. Actors solve this by isolating state and allowing work to happen through asynchronous message passing instead of direct access.

 ## Key Concepts

 * **Actor isolation**: the actor owns its mutable state and keeps it protected from unsynchronized access.
 * **Data race prevention**: outside code cannot read or write the actor's storage directly.
 * **Reentrancy**: actors can suspend work and continue later, without exposing their state to concurrent access.
 * **Message passing**: callers use `await` to send requests into the actor, and the actor serializes those requests.

 ---

 ## 1. Why shared state is risky

 Without actor isolation, two tasks can update the same variable at the same time. The final result is unpredictable because each task reads and writes the value without coordination.

 ```swift
 var sharedCounter = 0

 Task {
     for _ in 0..<1_000 {
         sharedCounter += 1
     }
 }

 Task {
     for _ in 0..<1_000 {
         sharedCounter += 1
     }
 }
 ```

 This pattern is unsafe because both tasks race on `sharedCounter`.
 */

actor BankAccount {
    private var balance: Int
    let accountID: String

    init(accountID: String, startingBalance: Int) {
        self.accountID = accountID
        self.balance = startingBalance
    }

    func deposit(_ amount: Int) {
        balance += amount
    }

    func withdraw(_ amount: Int) -> Bool {
        if amount <= balance {
            balance -= amount
            return true
        }
        return false
    }

    func currentBalance() -> Int {
        balance
    }
}

let account = BankAccount(accountID: "checking", startingBalance: 100)

Task {
    await account.deposit(50)
    let balance = await account.currentBalance()
    print("Balance after deposit: \(balance)")
}

/*:
 `await` is the boundary that moves execution into the actor. The actor serializes access to `balance`, so code outside the actor never reads or mutates it directly.

 ---

 ## 2. Concurrent calls stay safe

 Even when multiple tasks call into the same actor at once, each call is processed in order and the state remains consistent.
 */

Task {
    await withTaskGroup(of: Int.self) { group in
        for amount in 1...10 {
            group.addTask {
                await account.deposit(amount)
                return await account.currentBalance()
            }
        }

        var latestBalance = await account.currentBalance()
        for await balance in group {
            latestBalance = balance
        }

        print("Final balance after concurrent deposits: \(latestBalance)")
    }
}

/*:
 The actor is the single owner of the state. Tasks may compete to send requests, but the actor decides when each message is handled, eliminating data races.

 ---

 ## 3. Actor reentrancy

 An actor does not mean “only one task can ever run.” Instead, it means the actor’s mutable state is isolated and protected. A task can suspend while the actor is waiting on an async operation, and later resume without exposing mutable state to another task.
 
 
 actors do not lock across await suspension points. Whenever an actor-isolated function hits an await, it suspends execution and allows other tasks to enter the actor and read or mutate the actor's mutable properties before the original function resumes.

## How to prevent state bugs from reentrancy
 
Because Swift allows reentrancy by design (to prevent deadlocks and keep actors making forward progress), you have to structure your code around it:
* Mutate state synchronously: Keep all state reads, validations, and mutations together without an await in between. Synchronous code inside an actor cannot be interrupted.
* Re-check state after await: If you must perform an await (like a network call) before updating state, re-verify your actor's state after the await resumes before committing changes.
* Cache in-flight Tasks: If multiple callers might trigger the same async work simultaneously (e.g., fetching an image or token), store the running Task in a mutable property on the actor so subsequent callers await the existing task instead of starting duplicate work.

 */

actor MessageLogger {
    private var entries: [String] = []

    func add(_ entry: String) async {
        entries.append(entry)
        print("Logged: \(entry)")

        try? await Task.sleep(nanoseconds: 100_000_000)

        print("Finished logging: \(entry)")
    }

    func count() -> Int {
        entries.count
    }
}

let logger = MessageLogger()

Task {
    await logger.add("first")
    print("Messages logged: \(await logger.count())")
}

Task {
    await logger.add("second")
    print("Messages logged after second: \(await logger.count())")
}

/*:
 Actor isolation is not about blocking all concurrency. It is about ensuring that mutable state is touched by exactly one place at a time.

 ---

 ## 4. What actors are good for

 * protecting shared mutable state
 * coordinating background work that updates a model
 * avoiding data races when multiple tasks access the same resource
 * making your concurrency model easier to reason about

 ---

 ## 5. Mental model

 Think of an actor as a private room with a built-in gatekeeper. Outside code can ask for work, but it cannot walk in and mutate the room directly. The actor itself decides when to process each request, which keeps the data safe and the behavior predictable.
 */
//: [Next](@next)
