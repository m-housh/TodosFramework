import ComposableArchitecture
import SharedModels
import SwiftUI
import TodoClient

public struct TodoList: Reducer {
  
  public init() { }
  
  public struct State: Equatable {
    public var todos: IdentifiedArrayOf<Todo>
    
    public init(todos: IdentifiedArrayOf<Todo> = []) {
      self.todos = todos
    }
  }
  
  public enum Action: Equatable {
    case addTodoButtonTapped
    case deleteAllButtonTapped
    case didLoad(todos: [Todo])
    case viewDidAppear
  }
  
  @Dependency(\.todoClient) var todoClient;
  
  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
        
      case .addTodoButtonTapped:
        // fix
        return .run { send in
          _ = try await todoClient.insert(.init(title: "Test Todo", isComplete: Bool.random()))
          await send(.viewDidAppear)
        }
        
      case .deleteAllButtonTapped:
        return .run { send in
          try await todoClient.deleteAll()
          await send(.viewDidAppear)
        }
        
      case let .didLoad(todos: todos):
        state.todos = IdentifiedArray(uncheckedUniqueElements: todos)
        return .none
        
      case .viewDidAppear:
        return .run { send in
          try await send(.didLoad(todos: todoClient.fetch()))
        }
      }
    }
  }
}

public struct TodoListView: View {
  let store: StoreOf<TodoList>
  
  public init(store: StoreOf<TodoList>) {
    self.store = store
  }
  
  public var body: some View {
    WithViewStore(store, observe: { $0 }) { viewStore in
      NavigationStack {
        VStack {
          List {
            ForEach(viewStore.todos) { todo in
              HStack {
                Text(todo.title)
                Spacer()
                Image(systemName: todo.isComplete ? "checkmark.square" : "square")
              }
            }
          }
          Button(action: { viewStore.send(.deleteAllButtonTapped, animation: .easeOut) }) {
            Label("Delete All", systemImage: "trash")
              .foregroundColor(.red)
          }
        }
        .onAppear { viewStore.send(.viewDidAppear) }
        .navigationTitle("Todos")
        .toolbar {
          Button(action: { viewStore.send(.addTodoButtonTapped) }) {
            Label("Add", systemImage: "plus")
          }
        }
      }
    }
  }
}
