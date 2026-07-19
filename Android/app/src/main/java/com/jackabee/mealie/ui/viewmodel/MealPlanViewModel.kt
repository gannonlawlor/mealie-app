package com.jackabee.mealie.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.jackabee.mealie.data.api.MealieApiSource
import com.jackabee.mealie.data.model.CreateMealPlan
import com.jackabee.mealie.data.model.MealPlanEntry
import com.jackabee.mealie.data.model.MealType
import com.jackabee.mealie.data.store.CacheService
import com.jackabee.mealie.di.AppContainer
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.withContext
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

/** UI state for the meal plan tab. Port of the Swift MealPlanViewModel's observable properties. */
data class MealPlanUiState(
    val weekEntries: Map<String, List<MealPlanEntry>> = emptyMap(),
    val todayEntries: List<MealPlanEntry> = emptyList(),
    val isLoading: Boolean = false,
    val currentWeekStart: LocalDate = LocalDate.now(),
    val errorMessage: String = "",
    val errorDetail: String = "",
) {
    /** The 7 days shown, starting at [currentWeekStart] (start of today, like iOS). */
    val weekDates: List<LocalDate>
        get() = (0L..6L).map { currentWeekStart.plusDays(it) }
}

/** Port of ios/Sources/MealieModel/ViewModels/MealPlanViewModel.swift. */
class MealPlanViewModel(
    private val api: MealieApiSource,
    private val cache: CacheService,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
    private val today: () -> LocalDate = { LocalDate.now() },
) : ViewModel() {

    private val _uiState = MutableStateFlow(MealPlanUiState(currentWeekStart = today()))
    val uiState: StateFlow<MealPlanUiState> = _uiState.asStateFlow()

    // MARK: Loading

    suspend fun loadWeek() {
        val weekStart = _uiState.value.currentWeekStart
        val startDate = dateString(weekStart)
        val endDate = dateString(weekStart.plusDays(6))

        // Show cached data immediately
        if (_uiState.value.weekEntries.isEmpty()) {
            withContext(ioDispatcher) { cache.loadMealPlanWeek(startDate) }?.let { cached ->
                _uiState.update { it.copy(weekEntries = groupEntries(cached)) }
            }
        }

        _uiState.update {
            it.copy(isLoading = it.weekEntries.isEmpty(), errorMessage = "", errorDetail = "")
        }

        try {
            val response = withContext(ioDispatcher) { api.getMealPlans(startDate, endDate) }
            withContext(ioDispatcher) { cache.saveMealPlanWeek(response.items, startDate) }
            _uiState.update { it.copy(weekEntries = groupEntries(response.items), isLoading = false) }
        } catch (e: Exception) {
            println("Failed to load meal plans: $e")
            _uiState.update {
                if (it.weekEntries.isEmpty()) {
                    it.copy(errorMessage = "Failed to load meal plan.", errorDetail = errorDetail(e), isLoading = false)
                } else {
                    it.copy(isLoading = false)
                }
            }
        }
    }

    suspend fun loadToday() {
        try {
            val entries = withContext(ioDispatcher) { api.getTodayMealPlan() }
            _uiState.update { it.copy(todayEntries = entries) }
        } catch (e: Exception) {
            println("Failed to load today's meal plan: $e")
            _uiState.update {
                it.copy(errorMessage = "Failed to load today's meal plan.", errorDetail = errorDetail(e))
            }
        }
    }

    // MARK: Week navigation

    fun previousWeek() = _uiState.update { it.copy(currentWeekStart = it.currentWeekStart.minusDays(7)) }

    fun nextWeek() = _uiState.update { it.copy(currentWeekStart = it.currentWeekStart.plusDays(7)) }

    fun goToThisWeek() = _uiState.update { it.copy(currentWeekStart = today()) }

    // MARK: Mutations

    suspend fun addMealPlan(date: LocalDate, type: MealType, recipeId: String?) {
        val plan = CreateMealPlan(
            date = dateString(date),
            entryType = type.raw,
            recipeId = recipeId,
        )

        try {
            withContext(ioDispatcher) { api.createMealPlan(plan) }
            loadWeek()
        } catch (e: Exception) {
            println("Failed to create meal plan: $e")
            _uiState.update {
                it.copy(errorMessage = "Failed to add meal plan.", errorDetail = errorDetail(e))
            }
        }
    }

    suspend fun deleteMealPlan(id: Int) {
        try {
            withContext(ioDispatcher) { api.deleteMealPlan(id) }
            loadWeek()
        } catch (e: Exception) {
            println("Failed to delete meal plan: $e")
            _uiState.update {
                it.copy(errorMessage = "Failed to delete meal plan.", errorDetail = errorDetail(e))
            }
        }
    }

    // MARK: Private

    private fun groupEntries(entries: List<MealPlanEntry>): Map<String, List<MealPlanEntry>> =
        entries.groupBy { it.date ?: "" }

    companion object {
        private val DATE_FORMAT = DateTimeFormatter.ofPattern("yyyy-MM-dd")

        fun dateString(date: LocalDate): String = date.format(DATE_FORMAT)

        fun dayName(date: LocalDate): String =
            date.format(DateTimeFormatter.ofPattern("EEE", Locale.getDefault()))

        fun dayNumber(date: LocalDate): String =
            date.format(DateTimeFormatter.ofPattern("d", Locale.getDefault()))

        fun factory(container: AppContainer): ViewModelProvider.Factory = viewModelFactory {
            initializer {
                MealPlanViewModel(api = container.api, cache = container.cache)
            }
        }
    }
}
