import ComposableArchitecture
import Dependencies
import SharedModels
import SwiftUI
import TodoClient

public struct SimpleTodoList: Reducer {
  public init() { }
  
  public struct State: Equatable {
    public var todos: [Todo]
    
    public init(todos: [Todo] = []) {
      self.todos = todos
    }
  }
  
  public enum Action: Equatable {
    case loadTodos
    case loadingResult(TaskResult<[Todo]>)
    case viewDidAppear
  }
  
  @Dependency(\.todoClient) var todoClient;
  
  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .loadTodos:
        return .run { send in
          await send(
            .loadingResult(
              TaskResult { try await todoClient.fetchAll() }
            )
          )
        }
        
      case .loadingResult(.failure(let error)):
        print("Error: \(error)")
        return .none
        
      case .loadingResult(.success(let todos)):
        print("\(todos)")
        state.todos = todos
        return .none
        
      case .viewDidAppear:
        return .send(.loadTodos)
      }
    }
  }
}

public struct SimpleTodoListView: View {
  let store: StoreOf<SimpleTodoList>
  
  public init(store: StoreOf<SimpleTodoList>) {
    self.store = store
  }
  
  public var body: some View {
    WithViewStore(store, observe: { $0 }) { viewStore in
      NavigationStack {
        List(viewStore.todos) {
          Text($0.title)
        }
        .onAppear { viewStore.send(.viewDidAppear) }
        .navigationTitle("Todos: Count: \(viewStore.todos.count)")
        .toolbar {
          Button("Load") {
            viewStore.send(.loadTodos)
          }
        }
      }
    }
  }
}
