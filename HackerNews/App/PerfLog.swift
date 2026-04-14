// Lightweight performance instrumentation. Emits OS signpost intervals (visible
// in Instruments → Points of Interest) and DEBUG-only timing logs to the unified
// log (capture via `log show --predicate 'subsystem == "com.hackernews.app"'`).
import Foundation
import os

enum PerfLog {
    static let parser = OSSignposter(subsystem: subsystem, category: "parser")
    static let models = OSSignposter(subsystem: subsystem, category: "models")
    static let logger = Logger(subsystem: subsystem, category: "perf")

    private static let subsystem = "com.hackernews.app"

    @inline(__always)
    static func measure<T>(
        _ signposter: OSSignposter,
        _ name: StaticString,
        _ body: () throws -> T
    ) rethrows -> T {
        let state = signposter.beginInterval(name)
        #if DEBUG
        let t0 = CFAbsoluteTimeGetCurrent()
        #endif
        defer {
            signposter.endInterval(name, state)
            #if DEBUG
            let ms = (CFAbsoluteTimeGetCurrent() - t0) * 1000
            logger.info("\(String(describing: name), privacy: .public) \(ms, privacy: .public)ms")
            #endif
        }
        return try body()
    }
}
