import ComposableArchitecture
import SharedModels
import SwiftUI
import TodoClient

public struct TodoList: Reducer {
  
  public init() { }
  
  public struct State: Equatable {
    public var todos: IdentifiedArrayOf<TodoRow.State>
    @PresentationState public var destination: Destination.State?
    
    public init(
      todos: IdentifiedArrayOf<TodoRow.State> = [],
      destination: Destination.State? = nil
    ) {
      self.todos = todos
      self.destination = destination
    }
  }
  
  public enum Action: Equatable {
    case addTodoButtonTapped
    case deleteAllButtonTapped
    case destination(PresentationAction<Destination.Action>)
    case didLoad(todos: [Todo])
    case didSave(id: TodoRow.State.ID, todo: Todo)
    case refresh
    case todo(id: TodoRow.State.ID, action: TodoRow.Action)
    case viewDidAppear
  }

  public struct Destination: Reducer {
    public enum State: Equatable {
      case addTodo(AddTodo.State)
    }

    public enum Action: Equatable {
      case addTodo(AddTodo.Action)
    }

    public var body: some ReducerOf<Self> {
      Scope(state: /State.addTodo, action: /Action.addTodo) {
        AddTodo()
      }
    }
  }
  
  @Dependency(\.todoClient) var todoClient;
  
  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
        
      case .addTodoButtonTapped:
        state.destination = .addTodo(.init())
        return .none
        
      case .deleteAllButtonTapped:
        return .run { send in
          try await todoClient.deleteAll()
          await send(.viewDidAppear)
        }
        
      case let .destination(.presented(.addTodo(.didSave(todo: todo)))):
        state.todos[id: todo.id] = .init(todo: todo)
        state.destination = nil
        return .send(.destination(.dismiss))

      case .destination:
        return .none
        
      case let .didLoad(todos: todos):
        state.todos = IdentifiedArray(
          uncheckedUniqueElements: todos.map(TodoRow.State.init(todo:))
        )
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
          state.todos[id: todo.id] = .init(todo: todo)
          return .none
        }
        state.todos.remove(id: id)
        state.todos.insert(.init(todo: todo), at: index)
        return .none
        
      case .refresh:
        return .run { send in
          try await send(.didLoad(todos: todoClient.fetchAll()))
        }

      case let .todo(id: _, action: .didDelete(id: id)):
        state.todos.remove(id: id)
        return .none

      case .todo:
        return .none

      case .viewDidAppear:
        return .send(.refresh)
        
      }
    }
    .ifLet(\.$destination, action: /Action.destination) {
      Destination()
    }
    .forEach(\.todos, action: /Action.todo(id:action:)) {
      TodoRow()
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
            ForEachStore(
              store.scope(state: \.todos, action: TodoList.Action.todo(id:action:)),
              content: TodoRowView.init(store:)
            )
          }
          Button(action: { viewStore.send(.deleteAllButtonTapped, animation: .easeOut) }) {
            Label("Delete All", systemImage: "trash")
              .foregroundColor(.red)
          }
          .padding()
        }
        .navigationTitle("Todos")
        .onAppear { viewStore.send(.viewDidAppear) }
        .refreshable { viewStore.send(.refresh) }
        .toolbar {
          Button(action: { viewStore.send(.addTodoButtonTapped) }) {
            Label("Add", systemImage: "plus")
          }
        }
        .sheet(
          store: store.scope(state: \.$destination, action: TodoList.Action.destination),
          state: /TodoList.Destination.State.addTodo,
          action: TodoList.Destination.Action.addTodo
        ) { store in
          NavigationStack {
            AddTodoView(store: store)
              .padding()
              .navigationTitle("Add Todo")
              .frame(minWidth: 300, minHeight: 175)
              .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                  Button("Cancel") {
                    viewStore.send(.destination(.dismiss))
                  }
                }
              }
          }
        }
      }
    }
  }
}
