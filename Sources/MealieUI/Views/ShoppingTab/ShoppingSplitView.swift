import Foundation
import SkipFuse
#if os(Android)
import SkipFuseUI
#else
import SwiftUI
#endif
import MealieModel

struct ShoppingSplitView: View {
    @Bindable var shoppingVM: ShoppingViewModel
    @State var selectedListId: String? = nil
    @State var showNewListAlert = false
    @State var newListName = ""

    var body: some View {
        HStack(spacing: 0) {
            // Left: shopping lists
            NavigationStack {
                shoppingListColumn
                    .navigationTitle("Shopping Lists")
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button(action: { showNewListAlert = true }) {
                                Image(systemName: "plus")
                            }
                        }
                    }
                    .alert("New Shopping List", isPresented: $showNewListAlert) {
                        TextField("List name", text: $newListName)
                        Button("Cancel", role: .cancel) { newListName = "" }
                        Button("Create") {
                            Task {
                                await shoppingVM.createShoppingList(name: newListName)
                                newListName = ""
                            }
                        }
                    } message: {
                        Text("Enter a name for the new shopping list.")
                    }
            }
            .safeAreaPadding(.leading, 8)
            .frame(width: 340)

            Divider()

            // Right: detail
            NavigationStack {
                if let listId = selectedListId {
                    ShoppingListDetailView(shoppingVM: shoppingVM, listId: listId)
                        .id(listId)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "cart")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Select a shopping list")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .task {
            if shoppingVM.shoppingLists.isEmpty {
                await shoppingVM.loadShoppingLists()
            }
        }
    }

    var shoppingListColumn: some View {
        List {
            if shoppingVM.isLoading && shoppingVM.shoppingLists.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if shoppingVM.shoppingLists.isEmpty {
                Text("No shopping lists yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(shoppingVM.shoppingLists) { list in
                    Button(action: {
                        selectedListId = list.id
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(list.name ?? "Untitled")
                                    .font(.headline)
                                Text("\(list.uncheckedCount) items remaining")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if list.checkedCount > 0 {
                                Text("\(list.checkedCount) done")
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.15))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .listRowBackground(
                        selectedListId == list.id
                            ? Color.accentColor.opacity(0.12)
                            : Color.clear
                    )
                }
                .onDelete { offsets in
                    Task {
                        for index in offsets {
                            if let id = shoppingVM.shoppingLists[index].id {
                                if selectedListId == id {
                                    selectedListId = nil
                                }
                                await shoppingVM.deleteShoppingList(id: id)
                            }
                        }
                    }
                }
            }
        }
        .refreshable {
            await shoppingVM.loadShoppingLists()
        }
    }
}
