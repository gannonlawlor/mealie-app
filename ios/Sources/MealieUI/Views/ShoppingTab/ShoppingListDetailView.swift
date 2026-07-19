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
    @Environment(\.colorScheme) var colorScheme

    var uncheckedItems: [ShoppingListItem] {
        shoppingVM.selectedList?.listItems?.filter { $0.checked != true } ?? []
    }

    var checkedItems: [ShoppingListItem] {
        shoppingVM.selectedList?.listItems?.filter { $0.checked == true } ?? []
    }

    var pendingItems: [PendingGroceryItem] {
        LocalGroceryStore.shared.pendingItems(forListId: listId)
    }

    var body: some View {
        VStack(spacing: 0) {
            if !shoppingVM.errorMessage.isEmpty {
                ErrorBanner(message: shoppingVM.errorMessage, detail: shoppingVM.errorDetail) {
                    shoppingVM.errorMessage = ""
                    shoppingVM.errorDetail = ""
                }
                .padding(.top, 4)
            }

            if !shoppingVM.syncMessage.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(shoppingVM.syncMessage)
                        .font(.subheadline)
                    Spacer()
                    Button(action: { shoppingVM.syncMessage = "" }) {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.1))
            }

            // Add item bar
            HStack(spacing: 8) {
                TextField("Add an item...", text: $shoppingVM.newItemNote)
                    .padding(10)
                    .background(AdaptiveColors.color(.field, isDark: colorScheme == .dark))
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
                    // Pending upload section
                    if !pendingItems.isEmpty {
                        Section {
                            ForEach(Array(pendingItems.enumerated()), id: \.offset) { index, item in
                                HStack(spacing: 12) {
                                    Image(systemName: "arrow.up.circle")
                                        .foregroundStyle(.orange)
                                        .font(.title3)

                                    Text(item.note)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    Button(action: {
                                        LocalGroceryStore.shared.removePendingItem(atIndex: index, forListId: listId)
                                        shoppingVM.refreshPendingCounts()
                                    }) {
                                        Image(systemName: "trash")
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                    }
                                }
                            }

                            Button(action: {
                                Task { await shoppingVM.syncPendingItems(forListId: listId) }
                            }) {
                                HStack {
                                    if shoppingVM.isSyncing {
                                        ProgressView()
                                            .padding(.trailing, 4)
                                    }
                                    Label(
                                        shoppingVM.isSyncing ? "Uploading..." : "Upload \(pendingItems.count) items",
                                        systemImage: "arrow.up.circle.fill"
                                    )
                                }
                            }
                            .disabled(shoppingVM.isSyncing)
                        } header: {
                            Text("Pending Upload")
                        }
                    }

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

                    if uncheckedItems.isEmpty && checkedItems.isEmpty && pendingItems.isEmpty {
                        Text("No items in this list")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(shoppingVM.selectedList?.name ?? "Shopping List")
        .toolbar {
            if !pendingItems.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        Task { await shoppingVM.syncPendingItems(forListId: listId) }
                    }) {
                        if shoppingVM.isSyncing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.up.circle")
                        }
                    }
                    .disabled(shoppingVM.isSyncing)
                }
            }
        }
        .refreshable {
            await shoppingVM.loadShoppingList(id: listId)
        }
        .task {
            shoppingVM.refreshPendingCounts()
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
