import Foundation

#if DEBUG
func debugLog(_ category: String, _ message: @autoclosure () -> String) {
    print("[\(category)] \(message())")
}
#else
@inline(__always)
func debugLog(_ category: String, _ message: @autoclosure () -> String) {}
#endif
