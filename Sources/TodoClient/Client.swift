import Dependencies
@_exported import SharedModels
import XCTestDynamicOverlay

extension DependencyValues {
  public var todoClient: TodoClient {
    get { self[TodoClient.self] }
    set { self[TodoClient.self] = newValue }
  }
}

public struct TodoClient {
  public var deleteAll: () async throws -> Void
  public var fetch: () async throws -> [Todo]
  public var insert: (Todo.InsertRequest) async throws -> Todo
  
  public init(
    deleteAll: @escaping () async throws -> Void,
    fetch: @escaping () async throws -> [Todo],
    insert: @escaping (Todo.InsertRequest) async throws -> Todo
  ) {
    self.deleteAll = deleteAll
    self.fetch = fetch
    self.insert = insert
  }
}

extension TodoClient: TestDependencyKey {
  
  public static var testValue: Self {
    .init(
      deleteAll: unimplemented(),
      fetch: unimplemented(placeholder: []),
      insert: unimplemented(placeholder: .empty)
    )
  }
}
