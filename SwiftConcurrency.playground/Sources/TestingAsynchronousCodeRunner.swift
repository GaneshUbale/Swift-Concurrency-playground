import Foundation

public enum TestingAsynchronousCodeRunner {
    public enum TestError: Error, CustomStringConvertible {
        case assertionFailed(String)

        public var description: String {
            switch self {
            case .assertionFailed(let message):
                return message
            }
        }
    }

    public static func checkEqual<Value: Equatable>(
        _ value: Value,
        _ expected: Value,
        _ description: String
    ) throws {
        guard value == expected else {
            throw TestError.assertionFailed(
                "\(description): expected \(expected), got \(value)"
            )
        }
    }

    public static func run(
        _ name: String,
        operation: @Sendable () async throws -> Void
    ) async {
        do {
            try await operation()
            print("PASS: \(name)")
        } catch {
            print("FAIL: \(name) - \(error)")
        }
    }
}
