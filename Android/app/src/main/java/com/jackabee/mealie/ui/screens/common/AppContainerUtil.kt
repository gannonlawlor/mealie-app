package com.jackabee.mealie.ui.screens.common

import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext
import com.jackabee.mealie.MealieApplication
import com.jackabee.mealie.di.AppContainer

/** Resolves the app's manual DI container from the composition's context. */
@Composable
fun appContainer(): AppContainer =
    (LocalContext.current.applicationContext as MealieApplication).container
