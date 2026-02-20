import Foundation
import SkipFuse
#if os(Android)
import SkipFuseUI
#else
import SwiftUI
#endif
import MealieModel

struct ShoppingListsView: View {
    @Bindable var shoppingVM: ShoppingViewModel
    @State var showNewListAlert = false
    @State var newListName = ""

    var body: some View {
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
                    NavigationLink(value: list) {
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
                }
                .onDelete { offsets in
                    Task {
                        for index in offsets {
                            if let id = shoppingVM.shoppingLists[index].id {
                                await shoppingVM.deleteShoppingList(id: id)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Shopping Lists")
        .navigationDestination(for: ShoppingList.self) { list in
            ShoppingListDetailView(shoppingVM: shoppingVM, listId: list.id ?? "")
        }
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
        .refreshable {
            await shoppingVM.loadShoppingLists()
        }
        .task {
            if shoppingVM.shoppingLists.isEmpty {
                await shoppingVM.loadShoppingLists()
            }
        }
    }
}
