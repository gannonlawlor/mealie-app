package com.jackabee.mealie.ui.viewmodel

import com.jackabee.mealie.data.model.MealPlanEntry
import com.jackabee.mealie.data.model.MealPlanPaginatedResponse
import com.jackabee.mealie.data.model.MealType
import com.jackabee.mealie.data.model.MealieJson
import com.jackabee.mealie.data.store.CacheService
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.io.IOException
import java.time.LocalDate

class MealPlanViewModelTest {

    @get:Rule
    val mainRule = MainDispatcherRule()

    @get:Rule
    val tmp = TemporaryFolder()

    private val fixedToday: LocalDate = LocalDate.of(2026, 7, 15)

    private class Env(root: File, rule: MainDispatcherRule, today: LocalDate) {
        val api = FakeMealieApiSource()
        val cache = CacheService(File(root, "cache"), MealieJson)
        val vm = MealPlanViewModel(api, cache, rule.dispatcher) { today }
    }

    private fun env() = Env(tmp.root, mainRule, fixedToday)

    private fun entry(id: Int, date: String, type: String = "dinner", title: String? = null) =
        MealPlanEntry(id = id, date = date, entryType = type, title = title)

    // MARK: Week window

    @Test
    fun `currentWeekStart starts at today and spans seven days`() {
        val state = env().vm.uiState.value
        assertEquals(fixedToday, state.currentWeekStart)
        assertEquals(7, state.weekDates.size)
        assertEquals(fixedToday, state.weekDates.first())
        assertEquals(fixedToday.plusDays(6), state.weekDates.last())
    }

    @Test
    fun `week navigation moves by seven days and goToThisWeek resets`() {
        val env = env()
        env.vm.previousWeek()
        assertEquals(LocalDate.of(2026, 7, 8), env.vm.uiState.value.currentWeekStart)

        env.vm.nextWeek()
        env.vm.nextWeek()
        assertEquals(LocalDate.of(2026, 7, 22), env.vm.uiState.value.currentWeekStart)

        env.vm.goToThisWeek()
        assertEquals(fixedToday, env.vm.uiState.value.currentWeekStart)
    }

    @Test
    fun `date helpers format like the iOS app`() {
        assertEquals("2026-07-05", MealPlanViewModel.dateString(LocalDate.of(2026, 7, 5)))
        assertEquals("5", MealPlanViewModel.dayNumber(LocalDate.of(2026, 7, 5)))
        assertTrue(MealPlanViewModel.dayName(LocalDate.of(2026, 7, 5)).isNotBlank())
    }

    // MARK: loadWeek

    @Test
    fun `loadWeek requests the visible week and groups entries by date`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.api.getMealPlansHandler = { _, _ ->
            MealPlanPaginatedResponse(
                items = listOf(
                    entry(1, "2026-07-15", "breakfast"),
                    entry(2, "2026-07-15", "dinner"),
                    entry(3, "2026-07-16", "lunch"),
                ),
            )
        }

        env.vm.loadWeek()

        assertEquals(listOf("2026-07-15" to "2026-07-21"), env.api.getMealPlansCalls)
        val weekEntries = env.vm.uiState.value.weekEntries
        assertEquals(2, weekEntries["2026-07-15"]?.size)
        assertEquals(1, weekEntries["2026-07-16"]?.size)
        assertFalse(env.vm.uiState.value.isLoading)
        assertEquals("", env.vm.uiState.value.errorMessage)
    }

    @Test
    fun `loadWeek falls back to cache when network fails`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.cache.saveMealPlanWeek(listOf(entry(9, "2026-07-15", "dinner")), "2026-07-15")
        env.api.getMealPlansHandler = { _, _ -> throw IOException("offline") }

        env.vm.loadWeek()

        assertEquals(1, env.vm.uiState.value.weekEntries["2026-07-15"]?.size)
        // Errors are only surfaced when nothing is cached
        assertEquals("", env.vm.uiState.value.errorMessage)
        assertFalse(env.vm.uiState.value.isLoading)
    }

    @Test
    fun `loadWeek surfaces error when nothing is cached`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.api.getMealPlansHandler = { _, _ -> throw IOException("offline") }

        env.vm.loadWeek()

        assertEquals("Failed to load meal plan.", env.vm.uiState.value.errorMessage)
        assertEquals("Network error: offline", env.vm.uiState.value.errorDetail)
        assertTrue(env.vm.uiState.value.weekEntries.isEmpty())
    }

    @Test
    fun `loadWeek caches successful responses`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.api.getMealPlansHandler = { _, _ ->
            MealPlanPaginatedResponse(items = listOf(entry(1, "2026-07-15")))
        }

        env.vm.loadWeek()

        assertEquals(1, env.cache.loadMealPlanWeek("2026-07-15")?.size)
    }

    // MARK: Mutations

    @Test
    fun `addMealPlan posts the entry and reloads the week`() = runTest(mainRule.dispatcher) {
        val env = env()
        var serverEntries = emptyList<MealPlanEntry>()
        env.api.getMealPlansHandler = { _, _ -> MealPlanPaginatedResponse(items = serverEntries) }
        env.api.createMealPlanHandler = { plan ->
            val created = entry(42, plan.date, plan.entryType)
            serverEntries = serverEntries + created
            created
        }

        env.vm.addMealPlan(LocalDate.of(2026, 7, 16), MealType.LUNCH, recipeId = "r-1")

        val plan = env.api.createdMealPlans.single()
        assertEquals("2026-07-16", plan.date)
        assertEquals("lunch", plan.entryType)
        assertEquals("r-1", plan.recipeId)
        assertEquals(1, env.vm.uiState.value.weekEntries["2026-07-16"]?.size)
    }

    @Test
    fun `deleteMealPlan deletes then reloads`() = runTest(mainRule.dispatcher) {
        val env = env()
        var serverEntries = listOf(entry(7, "2026-07-15"))
        env.api.getMealPlansHandler = { _, _ -> MealPlanPaginatedResponse(items = serverEntries) }
        env.api.deleteMealPlanHandler = { id -> serverEntries = serverEntries.filterNot { it.id == id } }

        env.vm.loadWeek()
        assertEquals(1, env.vm.uiState.value.weekEntries.size)

        env.vm.deleteMealPlan(7)

        assertEquals(listOf(7), env.api.deletedMealPlanIds)
        assertTrue(env.vm.uiState.value.weekEntries.isEmpty())
    }

    @Test
    fun `addMealPlan failure sets error message`() = runTest(mainRule.dispatcher) {
        val env = env()
        env.api.createMealPlanHandler = { throw httpException(500, "cannot") }

        env.vm.addMealPlan(fixedToday, MealType.DINNER, recipeId = null)

        assertEquals("Failed to add meal plan.", env.vm.uiState.value.errorMessage)
        assertEquals("Server error 500: cannot", env.vm.uiState.value.errorDetail)
    }
}
