import Dependencies
import SharedModels
import SwiftUI
import TodoFeature
import TodoClientLive

@main
struct TodosApp: App {
  @Dependency(\.persistentContainer) var persistentContainer;
  @Environment(\.scenePhase) var scenPhase;

  var body: some Scene {
    WindowGroup {
      SimpleTodoListView(
        store: .init(
          initialState: .init(),
          reducer: SimpleTodoList()._printChanges()
            .dependency(\.todoClient, .liveValue)
        )
      )
//      TodoListView(
//        store: .init(
//          initialState: TodoList.State(),
//          reducer: TodoList()._printChanges()
//        ) {
//          $0.persistentContainer = persistentContainer
//          $0.todoClient = .liveValue
//        }
//      )
//      .onChange(of: scenPhase) { phase in
//        if !(phase == .active) {
//          _ = try? persistentContainer.saveViewContextIfNeeded()
//        }
//      }
    }
  }
}
