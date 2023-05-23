import CoreData
import Dependencies
import SharedModels
@_exported import TodoClient


extension TodoClient: DependencyKey {

  public static var liveValue: Self {
    @Dependency(\.persistentContainer) var container;
    
    return Self(
      deleteAll: { try await container.deleteAllTodos() },
      fetch: { try await container.fetchTodos() },
      insert: { try await container.insertTodo($0) }
    )
  }
}

fileprivate extension PersistentContainer {
  
  func fetchTodos() async throws -> [Todo] {
    try await self.withViewContext { context in
      try context.fetch(TodoEntity.fetchRequest())
        .map(Todo.init(entity:))
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
  
  func deleteAllTodos() async throws {
    try await self.withNewBackgroundContext { context in
      let request = NSBatchDeleteRequest(fetchRequest: TodoEntity.fetchRequest())
      request.resultType = .resultTypeCount
      try context.performAndWait {
        _ = try context.execute(request) as? NSBatchDeleteResult
        try context.save()
        context.reset()
      }
    }
  }
}
