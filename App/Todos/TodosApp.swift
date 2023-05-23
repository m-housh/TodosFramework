import Dependencies
import SharedModels
import SwiftUI
import TodoFeature

@main
struct TodosApp: App {
  @Dependency(\.persistentContainer) var persistentContainer;
  @Environment(\.scenePhase) var scenPhase;

  var body: some Scene {
    WindowGroup {
      TodoListView(
        store: .init(
          initialState: TodoList.State(),
          reducer: TodoList()._printChanges()
        )
      )
      .onChange(of: scenPhase) { phase in
        if !(phase == .active) {
          _ = try? persistentContainer.viewContext.saveIfNeeded()
        }
      }
    }
  }
}
