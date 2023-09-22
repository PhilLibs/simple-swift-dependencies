# Simple Swift Dependencies

A dependency management library which is an alternative version of the existing [swift-dependencies](https://github.com/pointfreeco/swift-dependencies) library.

[![CI](https://github.com/PhilLibs/simple-swift-dependencies/actions/workflows/ci.yml/badge.svg)](https://github.com/PhilLibs/simple-swift-dependencies/actions/workflows/ci.yml)


  * [Motivation](#motivation)
  * [Warning](#warning)
  * [Documentation](#documentation)
  * [Alternatives](#alternatives)
  * [License](#license)

## Motivation

The awesome dependency management library [swift-dependencies](https://github.com/pointfreeco/swift-dependencies) relies on `TaskLocal` and may add unneeded complexity if one just wants to make the dependency injection more ergonomic if the dependencies look like the following:

- a protocol / protocol witness
- a single live implementation of the defined protocol
- the dependency is injected through the initializer usually with a default value which is a singleton of the live implementation

This simple dependency management tries to solve this exact issue by simplifying [swift-dependencies](https://github.com/pointfreeco/swift-dependencies) a bit, i.e. by removing the abilitiy to overwrite dependencies via `withDepdencies`.
With this library it's only possible to overwrite the default dependency in a test context. Therefore, making it way more ergonomic for non-single entry point systems as described in the [swift-dependencies documentation](https://pointfreeco.github.io/swift-dependencies/main/documentation/dependencies/singleentrypointsystems).
If you want something different do *not* use this library and better stick to the alternatives.

However, it still has some of the benefits of [swift-dependencies](https://github.com/pointfreeco/swift-dependencies):

- allowing to decouple the definition of a dependency and it's live implementation
- detecting test and preview environments
- support supplying a separate default implementation for SwiftUI previews and the `#Preview` macro 
- runtime warning if a dependency gets accessed in a live environment without having a live implementation provided

## Warning

Be aware that unlike [swift-dependencies](https://github.com/pointfreeco/swift-dependencies) this library does *not* make the access to the dependency thread-safe, i.e. if the access to your dependency was not thread-safe while it was injected via the initializer it's still not thread-safe after the use of this library.

## Usage

### Registering dependencies

In order to register a custom dependency you need to do the following:

First you create a type that conforms to the ``DependencyKey`` protocol. The minimum implementation
you must provide is a ``DependencyKey/liveValue``, which is the value used when running the app in a
simulator or on device, and so it's appropriate for it to actually make network requests to an
external server:

```swift
private enum APIClientKey: DependencyKey {
  static let liveValue = APIClient.live
}
```

Finally, an extension must be made to `DependencyValues` to expose a computed property for the
dependency:

```swift
extension DependencyValues {
  var apiClient: APIClient {
    get { self[APIClientKey.self] }
    set { self[APIClientKey.self] = newValue }
  }
}
```

With those few steps completed you can instantly access your API client dependency from any part of
you code base:

```swift
final class TodosModel: ObservableObject {
  @Dependency(\.apiClient) var apiClient
  // ...
}
```

This will automatically use the live dependency in previews, simulators and devices.

### Override for testing
In tests you can override the dependency to return mock data:

```swift
func testFetchUser() async {
  // Initialize your mock and set the return values    
  let apiClientMock = APIClientMock()
  apiClientMock.fetchTodosReturnValue = Todo(id: 1, title: "Get milk")

  // Overwrite the apiClient dependency with the mock 
  DependencyValues.mockDependency(\.apiClient, with: apiClientMock)

  let model = TodosModel()

  await store.loadButtonTapped()
  XCTAssertEqual(
    model.todos,
    [Todo(id: 1, title: "Get milk")]
  )
}
```

## Documentation

The latest documentation for the Dependencies APIs is available [here](https://phillibs.github.io/simple-swift-dependencies/main/documentation/dependencies/).

## Alternatives

If you have a single entry point system like a SwiftUI app it's highly recommended to use the original [swift-dependencies](https://github.com/pointfreeco/swift-dependencies) library instead of this one.
Furthermore, there are many other dependency injection libraries in the Swift community. Each has its own set of
priorities and trade-offs that differ from Dependencies. Here are a few well-known examples:

  * [Cleanse](https://github.com/square/Cleanse)
  * [Factory](https://github.com/hmlongco/Factory)
  * [Needle](https://github.com/uber/needle)
  * [Swinject](https://github.com/Swinject/Swinject)
  * [Weaver](https://github.com/scribd/Weaver)

## License

This library is released under the MIT license. See [LICENSE](LICENSE) for details.