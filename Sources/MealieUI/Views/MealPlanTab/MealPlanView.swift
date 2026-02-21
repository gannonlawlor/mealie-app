import Foundation
import SkipFuse
#if os(Android)
import SkipFuseUI
#else
import SwiftUI
#endif
import MealieModel

struct MealPlanView: View {
    @Bindable var mealPlanVM: MealPlanViewModel
    @Bindable var recipeVM: RecipeViewModel
    @State var showAddSheet = false
    @State var selectedDate: Date = Date()
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            if !mealPlanVM.errorMessage.isEmpty {
                ErrorBanner(message: mealPlanVM.errorMessage) {
                    mealPlanVM.errorMessage = ""
                }
                .padding(.top, 4)
            }

            // Week navigation header
            weekHeader

            // Day columns
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(mealPlanVM.weekDates, id: \.self) { date in
                        daySection(date: date)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Meal Plan")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Today") {
                    mealPlanVM.goToThisWeek()
                    Task { await mealPlanVM.loadWeek() }
                }
            }
        }
        .refreshable {
            await mealPlanVM.loadWeek()
        }
        .task {
            await mealPlanVM.loadWeek()
        }
        .sheet(isPresented: $showAddSheet) {
            AddMealPlanView(
                mealPlanVM: mealPlanVM,
                recipeVM: recipeVM,
                date: selectedDate,
                isPresented: $showAddSheet
            )
        }
    }

    var weekHeader: some View {
        HStack {
            Button(action: {
                mealPlanVM.previousWeek()
                Task { await mealPlanVM.loadWeek() }
            }) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .padding(8)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(weekTitle)
                    .font(.headline)
            }

            Spacer()

            Button(action: {
                mealPlanVM.nextWeek()
                Task { await mealPlanVM.loadWeek() }
            }) {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .padding(8)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(AdaptiveColors.color(.surface, isDark: colorScheme == .dark))
    }

    var weekTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: mealPlanVM.currentWeekStart)
        let end = formatter.string(from: Calendar.current.date(byAdding: .day, value: 6, to: mealPlanVM.currentWeekStart) ?? mealPlanVM.currentWeekStart)
        return "\(start) - \(end)"
    }

    func daySection(date: Date) -> some View {
        let dateStr = MealPlanViewModel.dateString(date)
        let entries = mealPlanVM.weekEntries[dateStr] ?? []
        let isToday = Calendar.current.isDateInToday(date)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(MealPlanViewModel.dayName(date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(MealPlanViewModel.dayNumber(date))
                        .font(.title2)
                        .bold()
                        .foregroundStyle(isToday ? Color.accentColor : Color.primary)
                }

                Spacer()

                Button(action: {
                    selectedDate = date
                    showAddSheet = true
                }) {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                }
            }

            if entries.isEmpty {
                Text("No meals planned")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(entries) { entry in
                    mealEntryRow(entry)
                }
            }

            Divider()
        }
    }

    func mealEntryRow(_ entry: MealPlanEntry) -> some View {
        HStack(spacing: 10) {
            Image(systemName: entry.mealType.icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.mealType.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(entry.displayTitle)
                    .font(.subheadline)
                    .lineLimit(1)
            }

            Spacer()

            Button(role: .destructive) {
                if let id = entry.id {
                    Task { await mealPlanVM.deleteMealPlan(id: id) }
                }
            } label: {
                Image(systemName: "xmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(AdaptiveColors.color(.surface, isDark: colorScheme == .dark))
        .cornerRadius(8)
    }
}

struct AddMealPlanView: View {
    @Bindable var mealPlanVM: MealPlanViewModel
    @Bindable var recipeVM: RecipeViewModel
    let date: Date
    @Binding var isPresented: Bool
    @State var selectedMealType: MealType = .dinner
    @State var searchText: String = ""
    @State var searchResults: [RecipeSummary] = []
    @State var isSearching: Bool = false
    @Environment(\.colorScheme) var colorScheme

    var displayedRecipes: [RecipeSummary] {
        searchResults.isEmpty ? recipeVM.recipes : searchResults
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Meal type picker
                Picker("Meal Type", selection: $selectedMealType) {
                    ForEach(MealType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Recipe search
                TextField("Search recipes...", text: $searchText)
                    .padding()
                    .background(AdaptiveColors.color(.field, isDark: colorScheme == .dark))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .onSubmit {
                        Task { await searchRecipes() }
                    }

                // Results
                List {
                    if isSearching {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        ForEach(displayedRecipes) { recipe in
                            Button(action: {
                                Task {
                                    if let recipeId = recipe.id {
                                        await mealPlanVM.addMealPlan(
                                            date: date,
                                            type: selectedMealType,
                                            recipeId: recipeId
                                        )
                                    }
                                    isPresented = false
                                }
                            }) {
                                HStack {
                                    Text(recipe.name ?? "Untitled")
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Meal - \(MealPlanViewModel.dayName(date))")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
            .task {
                if recipeVM.recipes.isEmpty {
                    await recipeVM.loadRecipes(reset: true)
                }
            }
        }
    }

    func searchRecipes() async {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }
        isSearching = true
        do {
            let response = try await MealieAPI.shared.getRecipes(page: 1, perPage: 20, search: searchText)
            searchResults = response.items
        } catch {
            // ignore
        }
        isSearching = false
    }
}
