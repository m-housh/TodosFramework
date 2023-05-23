import ComposableArchitecture
import SharedModels
import SwiftUI
import TodoClient

public struct AddTodo: Reducer {
  
  public struct State: Equatable {
    @BindingState var todo: Todo
    
    public init(todo: Todo = .empty) {
      self.todo = todo
    }
  }
  
  public enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
    case didSave(todo: Todo)
    case saveButtonTapped
  }

  @Dependency(\.todoClient) var todoClient;

  public var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {

      case .binding:
        return .none

      case .didSave:
        return .none

      case .saveButtonTapped:
        return .run { [todo = state.todo] send in
          let saved = try await todoClient.insert(
            .init(title: todo.title, isComplete: todo.isComplete)
          )
          await send(.didSave(todo: saved))
        }
      }
    }
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
        TextField("Title", text: viewStore.binding(\.$todo.title))
        Toggle("Complete", isOn: viewStore.binding(\.$todo.isComplete))
      }
      .onSubmit { viewStore.send(.saveButtonTapped) }
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            viewStore.send(.saveButtonTapped)
          }
        }
      }
    }
  }
}
