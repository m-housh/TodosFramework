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

  @_spi(Internals)
  public var viewContext: NSManagedObjectContext { container.viewContext }
  
  public func saveViewContextIfNeeded() throws {
    try viewContext.saveIfNeeded()
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

// Taken from: https://github.com/AvdLee/CoreDataBestPractices/blob/main/CoreDataBestPractices/Best%20Practices/Saving.swift

/**
 In general: Save only if needed.
 The `saveIfNeeded` method below will help to achieve this automatically.
 Apart from that, you can still focus on calling this method only if needed.
 However, do consider: your data is only saved if you save :-)
 
 Another good practice is to save on termination & on background.
 See: `SceneDelegate.sceneDidEnterBackground(_:)`
 */
extension NSManagedObjectContext {

  /// Checks whether there are actually changes that will change the persistent store.
  /// The `hasChanges` method would return `true` for transient changes as well which can lead to false positives.
  var hasPersistentChanges: Bool {
    return !insertedObjects.isEmpty
    || !deletedObjects.isEmpty
    || updatedObjects.contains(where: { $0.hasPersistentChangedValues })
  }

  /// Saves the context, only if it has any changes and if it has a place to save the changes to (parent or persistent store). Calling this method instead of the regular save() will increase performance. It is also useful to use this function when having a memory store, since this configuration doesn't have a persistent store but may use parent contexts to save their changes to.
  /// - throws: A Core Data NSError when saving fails.
  /// - returns: Whether the save was needed.
  @discardableResult
  public func saveIfNeeded() throws -> Bool {
    let hasPurpose = parent != nil
    || persistentStoreCoordinator?.persistentStores.isEmpty == false

    guard hasPersistentChanges && hasPurpose else {
      // Saving won't do anything now, except for decreasing performance. Skip it for now.
      return false
    }

    try save()

    return true
  }
}
