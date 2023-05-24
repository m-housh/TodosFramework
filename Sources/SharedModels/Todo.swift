import CoreData
import Dependencies
import Foundation

public struct Todo: Equatable, Sendable, Identifiable {
  
//  @_spi(Internals)
//  @UncheckedSendable
//  public private(set) var _managedID: NSManagedObjectID
  
  public var id: UUID
  public var title: String
  public var isComplete: Bool
  public let lastModified: Date
  
  public init(
    id: UUID,
    title: String,
    isComplete: Bool,
    lastModified: Date
  ) {
    self.id = id
    self.title = title
    self.isComplete = isComplete
    self.lastModified = lastModified
//    self._managedID = .init()
  }
  
  public init(id: ID? = nil, entity: TodoEntity) {
    @Dependency(\.date.now) var now;
    @Dependency(\.uuid) var uuid;
    
    self.id = id ?? uuid()
//    self._managedID = entity.objectID
    self.title = entity.title ?? ""
    self.isComplete = entity.complete
    self.lastModified = entity.lastModified ?? now
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
    
    public init(
      title: String,
      isComplete: Bool
    ) {
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
