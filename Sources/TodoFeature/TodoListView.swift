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
    case delete(id: Todo.ID)
    case didLoad(todos: [Todo])
    case didSave(id: Todo.ID, todo: Todo)
    case refresh
    case toggleCompletedTapped(todo: Todo)
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
        
      case let .delete(id: id):
        state.todos.remove(id: id)
        return .fireAndForget {
          try await todoClient.delete(.id(id))
        }
        
      case let .didLoad(todos: todos):
        state.todos = IdentifiedArray(uncheckedUniqueElements: todos)
        return .none
        
      case let .didSave(id: id, todo: todo):
        guard let index = state.todos.index(id: id) else {
          XCTFail(
            """
            Recieved did save action on a todo that was not found in the current todos.
            
            This is considered an application logic error.
            
            ID: \(id)
            Todo: \(todo)
            
            """
          )
          state.todos[id: todo.id] = todo
          return .none
        }
        state.todos.remove(id: id)
        state.todos.insert(todo, at: index)
        return .none
        
      case .refresh:
        return .run { send in
          try await send(.didLoad(todos: todoClient.fetchAll()))
        }
        
      case var .toggleCompletedTapped(todo: todo):
        todo.isComplete.toggle()
        return .run { [todo = todo] send in
          let saved = try await todoClient.update(todo)
          await send(.didSave(id: todo.id, todo: saved))
        }
        
      case .viewDidAppear:
        return .send(.refresh)
        
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
                  .onTapGesture {
                    viewStore.send(.toggleCompletedTapped(todo: todo))
                  }
              }
              .swipeActions(allowsFullSwipe: true) {
                Button(role: .destructive) {
                  viewStore.send(.delete(id: todo.id))
                } label: {
                  Label("Delete", systemImage: "trash")
                }
              }
            }
          }
          Button(action: { viewStore.send(.deleteAllButtonTapped, animation: .easeOut) }) {
            Label("Delete All", systemImage: "trash")
              .foregroundColor(.red)
          }
        }
        .refreshable { viewStore.send(.refresh) }
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
