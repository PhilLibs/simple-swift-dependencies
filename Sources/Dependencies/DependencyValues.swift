import Foundation

/// A collection of dependencies that is globally available.
/// This is a version of the already existing and awesome package [swift-dependencies`](https://github.com/pointfreeco/swift-dependencies)
/// The difference is that all current dependencies are always globally available and can't  be overwritten outside of a test context.
///
/// To access a particular dependency from the collection you use the ``Dependency`` property
/// wrapper:
///
/// ```swift
/// @Dependency(\.date) var date
/// // ...
/// let now = date.now
/// ```
///
/// To register a dependency inside ``DependencyValues``, you first create a type to conform to the
/// ``DependencyKey`` protocol in order to specify the ``DependencyKey/liveValue`` to use for the
/// dependency when run in simulators and on devices. It can even be private:
///
/// ```swift
/// private enum MyValueKey: DependencyKey {
///   static let liveValue = 42
/// }
/// ```
///
/// And then extend ``DependencyValues`` with a computed property that uses the key to read and
/// write to ``DependencyValues``:
///
/// ```swift
/// extension DependencyValues {
///   var myValue: Int {
///     get { self[MyValueKey.self] }
///     set { self[MyValueKey.self] = newValue }
///   }
/// }
/// ```
///
/// With those steps done you can access the dependency using the ``Dependency`` property wrapper:
///
/// ```swift
/// @Dependency(\.myValue) var myValue
/// myValue  // 42
/// ```
///
/// Read the article <doc:RegisteringDependencies> for more information.
public struct DependencyValues: Sendable {
    static var _current = Self()
    @TaskLocal static var currentDependency = CurrentDependency()
    
    fileprivate var cachedValues = CachedValues()
    fileprivate var storage: [ObjectIdentifier: AnySendable] = [:]
    
    /// Creates a dependency values instance.
    ///
    /// You don't typically create an instance of ``DependencyValues`` directly. Doing so would
    /// provide access only to default values. Instead, you rely on the dependency values' instance
    /// that the library manages for you when you use the ``Dependency`` property wrapper.
    public init() {
#if canImport(XCTest)
        _ = setUpTestObservers
#endif
    }
    
    /// Accesses the dependency value associated with a custom key.
    ///
    /// This subscript is typically only used when adding a computed property to ``DependencyValues``
    /// for registering custom dependencies:
    ///
    /// ```swift
    /// private struct MyDependencyKey: DependencyKey {
    ///   static let testValue = "Default value"
    /// }
    ///
    /// extension DependencyValues {
    ///   var myCustomValue: String {
    ///     get { self[MyDependencyKey.self] }
    ///     set { self[MyDependencyKey.self] = newValue }
    ///   }
    /// }
    /// ```
    ///
    /// You use custom dependency values the same way you use system-provided values, setting a value
    /// with ``withDependencies(_:operation:)-4uz6m``, and reading values with the ``Dependency``
    /// property wrapper.
    public subscript<Key: TestDependencyKey>(
        key: Key.Type,
        file: StaticString = #file,
        function: StaticString = #function,
        line: UInt = #line
    ) -> Key.Value where Key.Value: Sendable {
        get {
            guard let base = self.storage[ObjectIdentifier(key)]?.base,
                  let dependency = base as? Key.Value
            else {
                let context =
                self.storage[ObjectIdentifier(DependencyContextKey.self)]?.base as? DependencyContext
                ?? defaultContext
                
                return self.cachedValues.value(
                    for: Key.self,
                    context: context,
                    file: file,
                    function: function,
                    line: line
                )
            }
            return dependency
        }
        set {
            self.storage[ObjectIdentifier(key)] = AnySendable(newValue)
        }
    }
    
    func merging(_ other: Self) -> Self {
        var values = self
        values.storage.merge(other.storage, uniquingKeysWith: { $1 })
        return values
    }
    
    /// Sets the context to a different one.
    ///
    /// It is only available for testing and can be used to change the ``DependencyContext`` from `DependencyContext.test` to something different.
    ///
    /// This can be used to unit test live dependencies for a special test case.
    ///
    /// ```swift
    /// func testFeatureThatUsesLiveDependencies() {
    ///   DependencyValues.setContext(to: .live) // Uses live dependencies as default
    ///   // Test feature with live dependencies
    /// }
    ///
    /// ``
    static func setContext(to newContext: DependencyContext) {
        _current.context = newContext
    }
    
    /// Overwrites the dependency for mocking.
    ///
    /// It is only available for testing and should be used to overwrite the default test dependency for mocking.
    ///
    /// ```swift
    /// func testFeatureThatUsesOverwrittenDependency() {
    ///   DependencyValues.mockDependency(\.myDependency, with: .mock) // Override dependency
    ///   // Test feature with dependency overridden
    /// }
    /// ```
    /// - Note: There is no scoping involved when overwritting the dependency for mocking. This means the mocked dependency is available globally.
    static func mockDependency<T>(_ keyPath: WritableKeyPath<DependencyValues, T>, with newValue: T) {
        _current[keyPath: keyPath] = newValue
    }
}

private struct AnySendable: @unchecked Sendable {
    let base: Any
    @inlinable
    init<Base: Sendable>(_ base: Base) {
        self.base = base
    }
}

struct CurrentDependency {
    var name: StaticString?
    var file: StaticString?
    var fileID: StaticString?
    var line: UInt?
}

private let defaultContext: DependencyContext = {
    let environment = ProcessInfo.processInfo.environment
    var inferredContext: DependencyContext {
        if environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return .preview
        } else if _XCTIsTesting {
            return .test
        } else {
            return .live
        }
    }
    
    guard let value = environment["SWIFT_DEPENDENCIES_CONTEXT"]
    else { return inferredContext }
    
    switch value {
    case "live":
        return .live
    case "preview":
        return .preview
    case "test":
        return .test
    default:
        runtimeWarn(
      """
      An environment value for SWIFT_DEPENDENCIES_CONTEXT was provided but did not match "live",
      "preview", or "test".
      
          SWIFT_DEPENDENCIES_CONTEXT = \(value.debugDescription)
      """
        )
        return inferredContext
    }
}()

private final class CachedValues: @unchecked Sendable {
    struct CacheKey: Hashable, Sendable {
        let id: ObjectIdentifier
        let context: DependencyContext
    }
    
    private let lock = NSRecursiveLock()
    fileprivate var cached = [CacheKey: AnySendable]()
    
    func value<Key: TestDependencyKey>(
        for key: Key.Type,
        context: DependencyContext,
        file: StaticString = #file,
        function: StaticString = #function,
        line: UInt = #line
    ) -> Key.Value where Key.Value: Sendable {
        self.lock.lock()
        defer { self.lock.unlock() }
        
        let cacheKey = CacheKey(id: ObjectIdentifier(key), context: context)
        guard let base = self.cached[cacheKey]?.base, let value = base as? Key.Value
        else {
            let value: Key.Value?
            switch context {
            case .live:
                value = _liveValue(key) as? Key.Value
            case .preview:
                value = Key.previewValue
            case .test:
                value = Key.testValue
            }
            
            guard let value = value
            else {
#if DEBUG
                    var dependencyDescription = ""
                    if let fileID = DependencyValues.currentDependency.fileID,
                       let line = DependencyValues.currentDependency.line
                    {
                        dependencyDescription.append(
                """
                  Location:
                    \(fileID):\(line)
                
                """
                        )
                    }
                    dependencyDescription.append(
                        Key.self == Key.Value.self
                        ? """
                  Dependency:
                    \(typeName(Key.Value.self))
                """
                        : """
                  Key:
                    \(typeName(Key.self))
                  Value:
                    \(typeName(Key.Value.self))
                """
                    )
                    
                    runtimeWarn(
              """
              "@Dependency(\\.\(function))" has no live implementation, but was accessed from a \
              live context.
              
              \(dependencyDescription)
              
              Every dependency registered with the library must conform to "DependencyKey", and \
              that conformance must be visible to the running application.
              
              To fix, make sure that "\(typeName(Key.self))" conforms to "DependencyKey" by \
              providing a live implementation of your dependency, and make sure that the \
              conformance is linked with this current application.
              """,
              file: DependencyValues.currentDependency.file ?? file,
              line: DependencyValues.currentDependency.line ?? line
                    )
                
#endif
                return Key.testValue
            }
            
            self.cached[cacheKey] = AnySendable(value)
            return value
        }
        
        return value
    }
}

// NB: We cannot statically link/load XCTest on Apple platforms, so we dynamically load things
//     instead on platforms where XCTest is available.
#if canImport(XCTest)
private let setUpTestObservers: Void = {
    if _XCTIsTesting {
#if canImport(ObjectiveC)
        DispatchQueue.mainSync {
            guard
                let XCTestObservation = objc_getProtocol("XCTestObservation"),
                let XCTestObservationCenter = NSClassFromString("XCTestObservationCenter"),
                let XCTestObservationCenter = XCTestObservationCenter as Any as? NSObjectProtocol,
                let XCTestObservationCenterShared =
                    XCTestObservationCenter
                    .perform(Selector(("sharedTestObservationCenter")))?
                    .takeUnretainedValue()
            else { return }
            let testCaseWillStartBlock: @convention(block) (AnyObject) -> Void = { _ in
                DependencyValues._current.cachedValues.cached = [:]
                DependencyValues._current.storage = [:]
            }
            let testCaseWillStartImp = imp_implementationWithBlock(testCaseWillStartBlock)
            class_addMethod(
                TestObserver.self, Selector(("testCaseWillStart:")), testCaseWillStartImp, nil)
            class_addProtocol(TestObserver.self, XCTestObservation)
            _ =
            XCTestObservationCenterShared
                .perform(Selector(("addTestObserver:")), with: TestObserver())
        }
#else
        XCTestObservationCenter.shared.addTestObserver(TestObserver())
#endif
    }
}()

#if canImport(ObjectiveC)
private final class TestObserver: NSObject {}

extension DispatchQueue {
    private static let key = DispatchSpecificKey<UInt8>()
    private static let value: UInt8 = 0
    
    fileprivate static func mainSync<R>(execute block: @Sendable () -> R) -> R {
        Self.main.setSpecific(key: Self.key, value: Self.value)
        if getSpecific(key: Self.key) == Self.value {
            return block()
        } else {
            return Self.main.sync(execute: block)
        }
    }
}
#else
import XCTest

private final class TestObserver: NSObject, XCTestObservation {
    func testCaseWillStart(_ testCase: XCTestCase) {
        DependencyValues._current.cachedValues.cached = [:]
        DependencyValues._current.storage = [:]
    }
}
#endif
#endif
