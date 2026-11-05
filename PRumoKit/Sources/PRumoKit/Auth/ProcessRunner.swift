import Foundation

public protocol ProcessRunner: Sendable {
    func run(_ executable: String, _ args: [String]) async throws -> (status: Int32, stdout: String)
}

public enum ProcessRunnerError: Error, Equatable {
    case timedOut
}

public struct SystemProcessRunner: ProcessRunner {
    public let timeout: Duration

    public init(timeout: Duration = .seconds(5)) {
        self.timeout = timeout
    }

    public func run(_ executable: String, _ args: [String]) async throws -> (status: Int32, stdout: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        let terminated = AsyncStream<Void>.makeStream()
        process.terminationHandler = { _ in
            terminated.continuation.yield()
            terminated.continuation.finish()
        }
        try process.run()

        let reader = Task.detached { output.fileHandleForReading.readDataToEndOfFile() }

        let timedOut = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                for await _ in terminated.stream { return false }
                return false
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return true
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }

        if timedOut && process.isRunning {
            process.terminate()
            reader.cancel()
            throw ProcessRunnerError.timedOut
        }

        let data = await reader.value
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }
}
