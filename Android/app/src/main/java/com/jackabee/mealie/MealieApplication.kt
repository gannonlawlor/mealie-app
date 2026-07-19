package com.jackabee.mealie

import android.app.Application
import com.jackabee.mealie.di.AppContainer

class MealieApplication : Application() {

    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        container = AppContainer(this)
    }
}
