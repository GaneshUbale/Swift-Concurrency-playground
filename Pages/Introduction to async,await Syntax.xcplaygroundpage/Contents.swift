//: [Previous](@previous)
/*:
 # Lesson: Introduction to async/await Syntax
 
 Swift Concurrency simplifies asynchronous code using `async` and `await`. It lets you write asynchronous code that reads sequentially, similar to synchronous code, avoiding complex completion handler callbacks.
 
 ## Key Concepts
 
 * **async**: Marks a function, method, or property as asynchronous, indicating that it can suspend execution.
 * **await**: Marks a potential suspension point where execution pauses until the asynchronous operation completes.
 
 ---
 
 ## 1. Defining an Async Function
 
 To mark a function as asynchronous, place the `async` keyword right after the parameter list and before the return type:
 */

// A simple function simulating a network fetch
func fetchUserData() async -> String {
    try? await Task.sleep(nanoseconds: 1_000_000_000) // Simulates an asynchronous operation (e.g., network request)
    return "User: Jane Doe"
}
/*:
 ## 2. Calling an Async Function
 
 Calling an `async` function requires the `await` keyword. Because execution can suspend, `async` functions can only be called from:
 1. Another `async` context.
 2. A `Task` block in synchronous code.
 */

func main() async {
    print("Fetching data...")
    
    // Execution pauses here until fetchUserData completes
    let user = await fetchUserData()
    
    print("Received: \(user)")
}

// Run the async function from a synchronous playground context
Task {
    await main()
}
/*:
 ## 3. Handling Errors with `async throws`
 
 Asynchronous functions often fail (e.g., network timeouts). You can combine `async` with `throws`. Note that `async` always comes before `throws`.
 */

enum NetworkError: Error {
    case badResponse
}

func fetchServerStatus() async throws -> String {
    try? await Task.sleep(nanoseconds: 500_000_000)
    let success = false
    if !success {
        throw NetworkError.badResponse
    }
    return "Server Online"
}

// Calling an async throwing function requires both `try` and `await`
func checkStatus() async {
    do {
        let status = try await fetchServerStatus()
        print(status)
    } catch {
        print("Failed to fetch status: \(error)")
    }
}

Task {
    await checkStatus()
}

/*:
 ---
 ## 🧠 Mental Model

 Think of asynchronous work as **Ordering Food at a Restaurant**:
 * **`async` (The kitchen may take time)**: An asynchronous function can pause while it waits for work to finish, such as a network request. The person serving you does not need to stand still during that wait.
 * **`await` (Waiting at the counter)**: This marks the exact point where your code may suspend until the requested result is ready. Once the food is prepared, execution continues with the next line.
 * **`Task` (Starting an order from outside the restaurant)**: Synchronous code can create a `Task` to begin asynchronous work, just as a customer places an order and lets the restaurant handle the preparation.
 * **`try await` (An order that may fail)**: When an asynchronous operation can throw an error, `try` acknowledges the possible failure and `await` acknowledges the possible suspension.
 */
//: [Next](@next)
