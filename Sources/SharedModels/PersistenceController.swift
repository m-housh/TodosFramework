import Dependencies
import CoreData
import Foundation

// Adapted from https://github.com/tgrapperon/swift-dependencies-additions

extension DependencyValues {
  public var persistentContainer: PersistentContainer {
    get { self[PersistentContainer.self] }
    set { self[PersistentContainer.self] = newValue }
  }
}

public struct PersistentContainer {
  fileprivate static let shared = PersistentContainer()
  
  fileprivate static var preview: PersistentContainer = {
    let result = PersistentContainer(inMemory: true)
    return result
  }()
  
  let container: NSPersistentCloudKitContainer
  
  public init(inMemory: Bool = false) {
    let bundle = Bundle.module
    let model = NSManagedObjectModel(
      contentsOf: bundle.url(forResource: "Model", withExtension: "momd")!
    )!
    container = NSPersistentCloudKitContainer(name: "Model", managedObjectModel: model)
    if inMemory {
      container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
    }
    container.loadPersistentStores(completionHandler: { (storeDescription, error) in
      if let error = error as NSError? {
        // Replace this implementation with code to handle the error appropriately.
        // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
        
        /*
         Typical reasons for an error here include:
         * The parent directory does not exist, cannot be created, or disallows writing.
         * The persistent store is not accessible, due to permissions or data protection when the device is locked.
         * The device is out of space.
         * The store could not be migrated to the current model version.
         Check the error message to determine what the actual problem was.
         */
        fatalError("Unresolved error \(error), \(error.userInfo)")
      }
    })
    container.viewContext.automaticallyMergesChangesFromParent = true
  }
}

extension PersistentContainer: DependencyKey {
  public static var liveValue: PersistentContainer { .shared }
  public static var previewValue: PersistentContainer { .preview }
  public static var testValue: PersistentContainer { .previewValue }
}

extension PersistentContainer {
  
  private func newChildViewContext() -> NSManagedObjectContext {
    let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    context.parent = container.viewContext
    return context
  }
  
  private func newBackgroundContext() -> NSManagedObjectContext {
    container.newBackgroundContext()
  }
  
  @MainActor
  public func withViewContext<R: Sendable>(
    perform: @MainActor (NSManagedObjectContext) throws -> R
  ) rethrows -> R {
    try perform(self.container.viewContext)
  }
  
  @MainActor
  public func withNewChildViewContext<R: Sendable>(
    perform: @MainActor (NSManagedObjectContext) throws -> R
  ) rethrows -> R {
    try perform(self.newChildViewContext())
  }
  
  public func withNewBackgroundContext<R: Sendable>(
    perform: (NSManagedObjectContext) throws -> R
  ) async throws -> R {
    try await self.withContext(self.newBackgroundContext(), perform: perform)
  }
  
  // Rethrow's diagnostic doesn't work well, so we explicitly provide an overload for non-throwing
  // closures.
  public func withNewBackgroundContext<R: Sendable>(
    perform: (NSManagedObjectContext) -> R
  ) async -> R {
    try! await self.withContext(self.newBackgroundContext(), perform: perform)
  }
  
  private func withContext<R: Sendable>(
    _ context: NSManagedObjectContext,
    perform: (NSManagedObjectContext) throws -> R
  ) async throws -> R {
    try await withCheckedThrowingContinuation { continuation in
      context.performAndWait {
        continuation.resume(
          with: Result {
            try perform(context)
          }
        )
      }
    }
  }
}
