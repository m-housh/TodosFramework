import ComposableArchitecture
import SharedModels
import SwiftUI
import TodoClient

public struct TodoList: Reducer {
  
  public init() { }
  
  public struct State: Equatable {
    public var todos: IdentifiedArrayOf<TodoRow.State>
    @PresentationState public var destination: Destination.State?
    var hasAppeard: Bool = false
    
    public init(
      todos: IdentifiedArrayOf<TodoRow.State> = [],
      destination: Destination.State? = nil
    ) {
      print("Init: TodoList.State")
      self.todos = todos
      self.destination = destination
    }
  }
  
  public enum Action: Equatable {
    case addTodoButtonTapped
    case deleteAllButtonTapped
    case destination(PresentationAction<Destination.Action>)
    case didLoadTodos(TaskResult<[Todo]>)
    case didLoad(todos: [Todo])
    case didSave(id: TodoRow.State.ID, todo: Todo)
    case refresh
    case todo(id: TodoRow.State.ID, action: TodoRow.Action)
    case viewDidAppear
    
    // remove
    case printState
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
        
      case let .didLoadTodos(.success(todos)):
        print("did load todos before: \(state.todos)")
        state.todos = IdentifiedArray(
          uncheckedUniqueElements: todos.map(TodoRow.State.init(todo:))
        )
        print("did load todos after: \(state.todos)")
        return .none
//        return .send(.didLoad(todos: todos))
        
      case let .didLoadTodos(.failure(error)):
        print("Failed to load todos: Error: \(error)")
        // fix
        return .none
        
      case let .didLoad(todos: todos):
        print("did load todos before: \(state.todos)")
        state.todos = IdentifiedArray(
          uncheckedUniqueElements: todos.map(TodoRow.State.init(todo:))
        )
        print("did load todos after: \(state.todos)")
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
          await send(
            .didLoadTodos(TaskResult { try await todoClient.fetchAll() })
//            .didLoad(todos: todoClient.fetchAll())
          )
//          let todos = try await todoClient.fetchAll()
//          await send(.didLoad(todos: todos))
        }

      case let .todo(id: _, action: .didDelete(id: id)):
        state.todos.remove(id: id)
        return .none

      case .todo:
        return .none

      case .viewDidAppear:
        guard state.hasAppeard else {
          state.hasAppeard = true
          return .run { send in
            await send(.refresh)
          }
        }
        return .none
        
        // remove
      case .printState:
        print(state.todos.count)
        print(state.todos)
        return .none
        
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
  
  struct ViewState: Equatable {
    let ids: Set<TodoRow.State.ID>
    
    init(state: TodoList.State) {
      self.ids = Set(state.todos.ids)
    }
  }
  
  public var body: some View {
    WithViewStore(store, observe: ViewState.init(state:)) { viewStore in
      NavigationStack {
        VStack {
          List {
            ForEachStore(
              store.scope(state: \.todos, action: TodoList.Action.todo(id:action:)),
              content: TodoRowView.init(store:)
            )
          }
          HStack {
            Button(action: { viewStore.send(.deleteAllButtonTapped, animation: .easeOut) }) {
              Label("Delete All", systemImage: "trash")
                .foregroundColor(.red)
            }
            .padding()
            
            Button(action: { viewStore.send(.printState) }) {
              Text("Print")
            }
          }
        }
        .navigationTitle("Todos: Count: \(viewStore.ids.count)")
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
