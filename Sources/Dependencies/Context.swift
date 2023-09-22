extension DependencyValues {
  /// The current dependency context.
  ///
  /// The current ``DependencyContext`` can be used to determine how dependencies are loaded by the
  /// current runtime.
  public var context: DependencyContext {
    get { self[DependencyContextKey.self] }
    set { self[DependencyContextKey.self] = newValue }
  }
}

enum DependencyContextKey: DependencyKey {
  static let liveValue = DependencyContext.live
  static let previewValue = DependencyContext.preview
    static let testValue = DependencyContext.test
}
