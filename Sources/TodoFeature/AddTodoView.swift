import ComposableArchitecture
import SharedModels
import SwiftUI

public struct AddTodo: Reducer {
  
  public struct State: Equatable {
    @BindingState var todo: Todo
    
    public init(todo: Todo = .empty) {
      self.todo = todo
    }
  }
  
  public enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
    case saveButtonTapped
  }
  
  public var body: some ReducerOf<Self> {
    BindingReducer()
  }
}

public struct AddTodoView: View {
  
  let store: StoreOf<AddTodo>
  
  public init(store: StoreOf<AddTodo>) {
    self.store = store
  }
  
  public var body: some View {
    WithViewStore(store, observe: { $0 }) { viewStore in
      Form {
        TextField("Todo title...", text: viewStore.binding(\.$todo.title))
        Toggle("Complete", isOn: viewStore.binding(\.$todo.isComplete))
      }
      .toolbar {
        Button("Save") {
          viewStore.send(.saveButtonTapped)
        }
      }
    }
  }
}
