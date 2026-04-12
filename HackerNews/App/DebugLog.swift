// Tiny debug-only logging shim so call sites can leave tracing in place without
// affecting release builds or pulling in a heavier logging dependency.
import Foundation

#if DEBUG
func debugLog(_ category: String, _ message: @autoclosure () -> String) {
    print("[\(category)] \(message())")
}
#else
@inline(__always)
func debugLog(_ category: String, _ message: @autoclosure () -> String) {}
#endif
