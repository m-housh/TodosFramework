import ComposableArchitecture
import Dependencies
import SharedModels
import SwiftUI
import TodoClient

public struct TodoRow: Reducer {
  public struct State: Equatable, Identifiable {
    public var id: Todo.ID { todo.id }
    public var todo: Todo

    public init(todo: Todo) {
      self.todo = todo
    }
  }

  public enum Action: Equatable {
    case deleteButtonTapped
    case didDelete(id: State.ID)
    case didSave(todo: Todo)
    case toggleCompleteButtonTapped
  }

  @Dependency(\.todoClient) var todoClient;

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {

      case .deleteButtonTapped:
        return .run { [id = state.todo.id] send in
          try await todoClient.delete(.id(id))
          await send(.didDelete(id: id))
        }

      case .didDelete:
        return .none

      case .toggleCompleteButtonTapped:
        state.todo.isComplete.toggle()
        return .run { [todo = state.todo] send in
          let saved = try await todoClient.update(todo)
          await send(.didSave(todo: saved))
        }

      case let .didSave(todo: todo):
        state.todo = todo
        return .none
      }
    }
  }

}

public struct TodoRowView: View {
  let store: StoreOf<TodoRow>

  public init(store: StoreOf<TodoRow>) {
    self.store = store
  }

  public var body: some View {
    WithViewStore(store, observe: { $0 }) { viewStore in
      VStack(alignment: .leading, spacing: 5){
        HStack {
          Text(viewStore.todo.title)
          Spacer()
          Image(systemName: viewStore.todo.isComplete ? "checkmark.square" : "square")
            .onTapGesture {
              viewStore.send(.toggleCompleteButtonTapped)
            }
        }
        Text(viewStore.todo.lastModified, formatter: dateFormatter)
          .foregroundColor(.secondary)
          .font(.caption)
      }
      .swipeActions(edge: .trailing, allowsFullSwipe: true) {
        Button(role: .destructive) {
          viewStore.send(.deleteButtonTapped)
        } label: {
          Label("Delete", systemImage: "trash")
        }
      }
      .contextMenu {
        Button(role: .destructive) {
          viewStore.send(.deleteButtonTapped)
        } label: {
          Label("Delete", systemImage: "trash")
        }
      }
    }
  }
}

fileprivate let dateFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.dateStyle = .long
  formatter.timeStyle = .medium
  return formatter
}()

#if DEBUG
struct SwiftUIView_Previews: PreviewProvider {
  static var previews: some View {
    TodoRowView(
      store: .init(
        initialState: TodoRow.State(todo: .empty),
        reducer: TodoRow()
      )
    )
  }
}
#endif
