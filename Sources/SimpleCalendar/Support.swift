import Combine
import Foundation

/// A tiny observable box used instead of `@State`.
///
/// `@State` is a compiler macro in the macOS 27 SDK, and its plugin ships only
/// with Xcode. This machine has just the Command Line Tools, so the app uses
/// `@StateObject` (an ordinary struct property wrapper) with this box instead.
final class Ref<Value>: ObservableObject {
    @Published var value: Value

    init(_ value: Value) {
        self.value = value
    }
}
