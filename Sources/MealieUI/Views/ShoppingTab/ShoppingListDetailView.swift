import Foundation
import SkipFuse
#if os(Android)
import SkipFuseUI
#else
import SwiftUI
#endif
import MealieModel

struct ShoppingListDetailView: View {
    @Bindable var shoppingVM: ShoppingViewModel
    let listId: String

    var uncheckedItems: [ShoppingListItem] {
        shoppingVM.selectedList?.listItems?.filter { $0.checked != true } ?? []
    }

    var checkedItems: [ShoppingListItem] {
        shoppingVM.selectedList?.listItems?.filter { $0.checked == true } ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            if !shoppingVM.errorMessage.isEmpty {
                ErrorBanner(message: shoppingVM.errorMessage) {
                    shoppingVM.errorMessage = ""
                }
                .padding(.top, 4)
            }

            // Add item bar
            HStack(spacing: 8) {
                TextField("Add an item...", text: $shoppingVM.newItemNote)
                    .padding(10)
                    .background(Color(white: 0.9))
                    .cornerRadius(8)

                Button(action: {
                    Task { await shoppingVM.addItem(toListId: listId) }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }
                .disabled(shoppingVM.newItemNote.isEmpty)
            }
            .padding()

            // Items list
            List {
                if shoppingVM.isLoading && shoppingVM.selectedList == nil {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else {
                    if !uncheckedItems.isEmpty {
                        Section("To Buy") {
                            ForEach(uncheckedItems) { item in
                                shoppingItemRow(item)
                            }
                        }
                    }

                    if !checkedItems.isEmpty {
                        Section("Completed") {
                            ForEach(checkedItems) { item in
                                shoppingItemRow(item)
                            }
                        }
                    }

                    if uncheckedItems.isEmpty && checkedItems.isEmpty {
                        Text("No items in this list")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(shoppingVM.selectedList?.name ?? "Shopping List")
        .refreshable {
            await shoppingVM.loadShoppingList(id: listId)
        }
        .task {
            await shoppingVM.loadShoppingList(id: listId)
        }
    }

    func shoppingItemRow(_ item: ShoppingListItem) -> some View {
        HStack(spacing: 12) {
            Button(action: {
                Task { await shoppingVM.toggleItem(item) }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: item.checked == true ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(item.checked == true ? .green : .secondary)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.displayText)
                            .strikethrough(item.checked == true)
                            .foregroundStyle(item.checked == true ? .secondary : .primary)

                        if let note = item.note, !note.isEmpty, item.food != nil {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }
            }

            Button(action: {
                Task { await shoppingVM.deleteItem(item) }
            }) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}
