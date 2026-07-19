package com.jackabee.mealie

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.jackabee.mealie.ui.navigation.AppNavHost
import com.jackabee.mealie.ui.theme.MealieTheme

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val container = (application as MealieApplication).container
        setContent {
            MealieTheme(themePreference = container.settings.theme) {
                Surface(modifier = Modifier.fillMaxSize()) {
                    MealieApp()
                }
            }
        }
    }
}

@Composable
fun MealieApp() {
    AppNavHost()
}
