import CoreData
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
  public var delete: (DeleteRequest) async throws -> Void
  public var fetch: (FetchRequest) async throws -> [Todo]
  public var insert: (Todo.InsertRequest) async throws -> Todo
  public var update: (Todo) async throws -> Todo
  
  public init(
    delete: @escaping (DeleteRequest) async throws -> Void,
    fetch: @escaping (FetchRequest) async throws -> [Todo],
    insert: @escaping (Todo.InsertRequest) async throws -> Todo,
    update: @escaping (Todo) async throws -> Todo
  ) {
    self.delete = delete
    self.fetch = fetch
    self.insert = insert
    self.update = update
  }
  
  public enum DeleteRequest {
    case all
    case todos([Todo])
    case objectIDs([NSManagedObjectID])
    
    public static func id(_ id: NSManagedObjectID) -> Self {
      .objectIDs([id])
    }
    
    public static func todo(_ todo: Todo) -> Self {
      .todos([todo])
    }
  }
  
  public enum FetchRequest {
    case all
    case sorted(by: [NSSortDescriptor])
  }
  
  public func deleteAll() async throws -> Void {
    try await self.delete(.all)
  }
  
  public func fetchAll() async throws -> [Todo] {
    try await self.fetch(.all)
  }
}

extension TodoClient: TestDependencyKey {
  
  public static var testValue: Self {
    Self.init(
      delete: unimplemented(),
      fetch: unimplemented(placeholder: []),
      insert: unimplemented(placeholder: .empty),
      update: unimplemented(placeholder: .empty)
    )
  }
}
