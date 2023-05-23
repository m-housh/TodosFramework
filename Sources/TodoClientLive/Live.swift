import CoreData
import Dependencies
@_spi(Internals) import SharedModels
@_exported import TodoClient


extension TodoClient: DependencyKey {
  
  public static func live(container: PersistentContainer) -> Self {
    .init(
      delete: { try await container.deleteTodos($0) },
      fetch: { try await container.fetchTodos($0) },
      insert: { try await container.insertTodo($0) },
      update: { try await container.updateTodo($0) }
    )
  }

  public static var liveValue: Self {
    @Dependency(\.persistentContainer) var container;
    return .live(container: container)
  }
}

fileprivate extension TodoClient.FetchRequest {
  
  var sortDescriptors: [NSSortDescriptor]? {
    switch self {
    case .all:
      return [
        NSSortDescriptor(key: #keyPath(TodoEntity.lastModified), ascending: false)
      ]
    case let .sorted(by: sortDescriptors):
      return sortDescriptors
    }
  }
}

fileprivate extension TodoClient.DeleteRequest {
  
  var batchDeleteRequest: NSBatchDeleteRequest {
    switch self {
    case .all:
      return .init(fetchRequest: TodoEntity.fetchRequest())
    case let .todos(todos):
      return .init(objectIDs: todos.map(\._managedID))
    case let .objectIDs(objectIDs):
      return .init(objectIDs: objectIDs)
    }
  }
}

fileprivate extension PersistentContainer {

  func fetchTodos(_ fetchRequest: TodoClient.FetchRequest) async throws -> [Todo] {
    try await self.withViewContext { context in
      // Create fetch request.
      let request = TodoEntity.fetchRequest()
      
      // Apply sort descriptors if applicable
      if let sortDescriptors = fetchRequest.sortDescriptors {
        request.sortDescriptors = sortDescriptors
      }
      
      // Fetch the results and turn them into `Todo` instances.
      return try context.fetch(request)
        .map { entity in
          Todo.init(entity: entity)
        }
    }
  }
  
  func insertTodo(_ request: Todo.InsertRequest) async throws -> Todo {
    try await self.withViewContext { context in
      let todo = TodoEntity(context: context)
      todo.title = request.title
      todo.complete = request.isComplete
      try context.save()
      return .init(entity: todo)
    }
  }
  
  func deleteTodos(_ deleteRequest: TodoClient.DeleteRequest) async throws {
    try await self.withNewBackgroundContext { context in
      let request = deleteRequest.batchDeleteRequest
      request.resultType = .resultTypeStatusOnly
      try context.performAndWait {
        // Fix to check for failures.
        _ = try context.execute(request) as? NSBatchDeleteResult
        try context.save()
        context.reset()
      }
    }
  }
  
  func updateTodo(_ todo: Todo) async throws -> Todo {
    @Dependency(\.date.now) var now;

    return try await self.withNewBackgroundContext { context in
      guard let entity = try context.existingObject(with: todo._managedID) as? TodoEntity
      else {
        XCTFail("Tried to update a todo that was not found in core data.")
        return todo
      }

      entity.title = todo.title
      entity.complete = todo.isComplete
      entity.lastModified = now

      do {
        try context.saveIfNeeded()
        return Todo(id: todo.id, entity: entity)
      } catch {
        context.rollback()
        throw error
      }
    }
  }
}
