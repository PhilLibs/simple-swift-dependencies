import XCTest
@testable import Dependencies

final class DependenciesTests: XCTestCase {
    
    func test_defaultsToTestValue() {
        @Dependency(\.mock) var mockDependency
        // GIVEN
        // the injected dependency has not been changed in the test case
        
        // THEN
        // it defaults to the given testValue of the corresponding dependency key.
        XCTAssertEqual(mockDependency, .test)
        XCTAssertEqual(mockDependency, MockDependencyKey.testValue)
    }
    
    func test_canBeChanged() throws {
        @Dependency(\.mock) var mockDependency
        // GIVEN
        // initially the mockDependency defaults to the test value
        XCTAssertEqual(mockDependency, .test)
        
        // WHEN
        // setting the mockDependency to something different
        DependencyValues.mockDependency(\.mock, with: .custom("MyCustom-Mock"))
        
        // then the injected dependency reflects this
        XCTAssertEqual(mockDependency, .custom("MyCustom-Mock"))
    }
    
    func test_canBeChangedGlobally() {
        // GIVEN
        // the mockDependency has been set to a custom value
        @Dependency(\.mock) var mockDependency
        DependencyValues.mockDependency(\.mock, with: .custom("MyCustom-Mock"))
        
        // WHEN
        // creating a object which uses this dependency
        let testObject = TestStruct()
        
        // THEN
        // it also returns the custom value from the injected dependency.
        XCTAssertEqual(testObject.value, .custom("MyCustom-Mock"))
    }
    
    func test_missingLiveValue() {
        #if DEBUG && !os(Linux) && !os(WASI) && !os(Windows)
          var line = 0
          XCTExpectFailure {
              DependencyValues.setContext(to: .live)
              line = #line + 1
              @Dependency(\.missingLiveDependency) var missingLiveDependency: Int
              _ = missingLiveDependency
          } issueMatcher: {
            $0.compactDescription == """
              "@Dependency(\\.missingLiveDependency)" has no live implementation, but was accessed \
              from a live context.

                Location:
                  DependenciesTests/DependenciesTests.swift:\(line)
                Key:
                  TestKey
                Value:
                  Int

              Every dependency registered with the library must conform to "DependencyKey", and that \
              conformance must be visible to the running application.

              To fix, make sure that "TestKey" conforms to "DependencyKey" by providing a live \
              implementation of your dependency, and make sure that the conformance is linked with \
              this current application.
              """
          }
        #endif
      }
}


fileprivate extension DependencyValues {
    var mock: MockDependency {
        get { self[MockDependencyKey.self] }
        set { self[MockDependencyKey.self] = newValue }
    }
}

fileprivate enum MockDependency: Equatable {
    case live
    case preview
    case test
    case custom(String)
}

fileprivate enum MockDependencyKey: DependencyKey {
    static let liveValue = MockDependency.live
    static let previewValue = MockDependency.preview
    static let testValue = MockDependency.test
}

fileprivate struct TestStruct {
    var value: MockDependency {
        @Dependency(\.mock) var mockDependency
        return mockDependency
    }
}

extension DependencyValues {
    fileprivate var missingLiveDependency: Int {
        self[TestKey.self]
    }
}

private enum TestKey: TestDependencyKey {
    static let testValue = 42
}
