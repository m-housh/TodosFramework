import Dependencies
import DependenciesAdditions
import SharedModels
import SwiftUI
import TodoClientLive
import TodoFeature

@main
struct TodosApp: App {
  
  var body: some Scene {
    WindowGroup {
      TodoListView(
        store: .init(
          initialState: TodoList.State(),
          reducer: TodoList()._printChanges()
        )
      )
    }
  }
}
