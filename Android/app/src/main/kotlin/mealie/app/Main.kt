package mealie.app

import skip.lib.*
import skip.model.*
import skip.foundation.*
import skip.ui.*

import android.app.Application
import android.content.Intent
import android.net.Uri
import androidx.activity.enableEdgeToEdge
import androidx.activity.compose.setContent
import androidx.appcompat.app.AppCompatActivity
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier

internal val logger: SkipLogger = SkipLogger(subsystem = "com.jackabee.mealie", category = "MealieApp")

open class AndroidAppMain: Application {
    constructor() {
    }

    override fun onCreate() {
        super.onCreate()
        logger.info("starting MealieApp")
        ProcessInfo.launch(applicationContext)
    }

    companion object {
    }
}

open class MainActivity: AppCompatActivity {
    constructor() {
    }

    private fun convertSendIntent(intent: Intent): Intent {
        if (intent.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
            if (sharedText != null) {
                // Extract URL from shared text (may contain extra text around it)
                val urlPattern = java.util.regex.Pattern.compile("https?://\\S+")
                val matcher = urlPattern.matcher(sharedText)
                val url = if (matcher.find()) matcher.group() else sharedText
                intent.action = Intent.ACTION_VIEW
                intent.data = Uri.parse(url)
                logger.info("converted SEND intent to VIEW: $url")
            }
        }
        return intent
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        logger.info("starting activity")
        convertSendIntent(intent)
        UIApplication.launch(this)
        enableEdgeToEdge()

        setContent {
            val saveableStateHolder = rememberSaveableStateHolder()
            saveableStateHolder.SaveableStateProvider(true) {
                PresentationRootView(ComposeContext())
                SideEffect { saveableStateHolder.removeState(true) }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        convertSendIntent(intent)
        super.onNewIntent(intent)
    }

    override fun onSaveInstanceState(outState: android.os.Bundle): Unit = super.onSaveInstanceState(outState)

    companion object {
    }
}

@Composable
internal fun PresentationRootView(context: ComposeContext) {
    val colorScheme = if (isSystemInDarkTheme()) ColorScheme.dark else ColorScheme.light
    PresentationRoot(defaultColorScheme = colorScheme, context = context) { ctx ->
        val contentContext = ctx.content()
        Box(modifier = ctx.modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            RootView().Compose(context = contentContext)
        }
    }
}
