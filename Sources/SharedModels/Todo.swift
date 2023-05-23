import CoreData
import Dependencies
import Foundation

public struct Todo: Equatable, Sendable, Identifiable {
  
  @UncheckedSendable public var id: NSManagedObjectID
  public var title: String
  public var isComplete: Bool
  public let lastModified: Date
  
  public init(
    id: NSManagedObjectID,
    title: String,
    isComplete: Bool,
    lastModified: Date
  ) {
    self.id = id
    self.title = title
    self.isComplete = isComplete
    self.lastModified = lastModified
  }
  
  public init(entity: TodoEntity) {
    self.id = entity.objectID
    self.title = entity.title ?? ""
    self.isComplete = entity.complete
    self.lastModified = entity.lastModified ?? Date()
  }
}

extension Todo {
  public static let empty = Self.init(
    id: .init(),
    title: "",
    isComplete: false,
    lastModified: Date()
  )
}

extension Todo {
  public struct InsertRequest: Equatable {
    public let title: String
    public let isComplete: Bool
    
    public init(title: String, isComplete: Bool) {
      self.title = title
      self.isComplete = isComplete
    }
  }
}

extension TodoEntity {
  public override func awakeFromInsert() {
    super.awakeFromInsert()
    setPrimitiveValue(Date(), forKey: #keyPath(TodoEntity.lastModified))
  }
}
