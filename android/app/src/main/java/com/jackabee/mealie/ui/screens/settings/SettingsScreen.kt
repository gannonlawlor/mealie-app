package com.jackabee.mealie.ui.screens.settings

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Logout
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Dns
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.AlertDialog
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.jackabee.mealie.data.settings.ThemePreference
import com.jackabee.mealie.ui.screens.common.ThemeController
import com.jackabee.mealie.ui.screens.common.appContainer
import com.jackabee.mealie.ui.screens.login.LoginScreen
import com.jackabee.mealie.ui.viewmodel.AuthViewModel
import com.jackabee.mealie.ui.viewmodel.ShoppingViewModel
import kotlinx.coroutines.launch

/**
 * Port of ios/Sources/MealieUI/Views/SettingsTab/SettingsView.swift,
 * minus the iOS-only rows (Reminders, iCloud sync).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(authViewModel: AuthViewModel, shoppingViewModel: ShoppingViewModel) {
    val container = appContainer()
    val settings = container.settings

    val authState by authViewModel.uiState.collectAsStateWithLifecycle()
    val shoppingState by shoppingViewModel.uiState.collectAsStateWithLifecycle()
    val isSyncing by container.recipeSyncService.isSyncing.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()

    var selectedTheme by remember { mutableStateOf(settings.theme) }
    var keepScreenAwake by remember { mutableStateOf(settings.keepScreenAwake) }
    var localGroceryList by remember { mutableStateOf(settings.localGroceryList) }
    var defaultListId by remember { mutableStateOf(settings.defaultShoppingListId ?: "") }
    var showLogoutDialog by remember { mutableStateOf(false) }
    var showLoginDialog by remember { mutableStateOf(false) }
    var localRecipeCountRefresh by remember { mutableIntStateOf(0) }

    val syncedCount = remember(isSyncing) { container.recipeSyncService.syncedRecipeCount }
    val localRecipeCount by produceState(initialValue = 0, localRecipeCountRefresh) {
        value = container.localRecipeStore.recipeCount()
    }

    LaunchedEffect(authState.isServerConnected) {
        if (authState.isServerConnected) {
            authViewModel.loadServerInfo()
            if (shoppingViewModel.uiState.value.shoppingLists.isEmpty()) {
                shoppingViewModel.loadShoppingLists()
            }
        } else {
            localRecipeCountRefresh += 1
        }
    }

    // Close the connect-to-server login dialog once connected/authenticated.
    LaunchedEffect(authState.isServerConnected, authState.isAuthenticated) {
        if (showLoginDialog && (authState.isServerConnected || authState.isAuthenticated)) {
            showLoginDialog = false
        }
    }

    Scaffold(
        topBar = { TopAppBar(title = { Text("Settings") }) },
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            // Appearance
            SettingsSection(header = "Appearance") {
                Column(modifier = Modifier.padding(12.dp)) {
                    SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                        ThemePreference.entries.forEachIndexed { index, pref ->
                            SegmentedButton(
                                selected = selectedTheme == pref,
                                onClick = {
                                    selectedTheme = pref
                                    settings.theme = pref
                                    ThemeController.theme = pref
                                },
                                shape = SegmentedButtonDefaults.itemShape(
                                    index = index,
                                    count = ThemePreference.entries.size,
                                ),
                            ) {
                                Text(
                                    when (pref) {
                                        ThemePreference.SYSTEM -> "System"
                                        ThemePreference.LIGHT -> "Light"
                                        ThemePreference.DARK -> "Dark"
                                    }
                                )
                            }
                        }
                    }
                }
            }

            // Keep screen awake
            SettingsSection(footer = "Prevents the screen from dimming while viewing a recipe.") {
                ToggleRow(
                    title = "Keep Screen Awake",
                    checked = keepScreenAwake,
                    onCheckedChange = {
                        keepScreenAwake = it
                        settings.keepScreenAwake = it
                    },
                )
            }

            // Shopping list preferences (server mode)
            if (authState.isServerConnected) {
                SettingsSection(
                    header = "Shopping Lists",
                    footer = "Set a default list to skip the picker when adding ingredients. " +
                        "Queue locally to save items offline and upload later.",
                ) {
                    DefaultListRow(
                        selectedId = defaultListId,
                        lists = shoppingState.shoppingLists.mapNotNull { list ->
                            list.id?.let { it to (list.name ?: "Untitled") }
                        },
                        onSelect = { id, name ->
                            defaultListId = id
                            if (id.isEmpty()) {
                                settings.defaultShoppingListId = null
                                settings.defaultShoppingListName = null
                            } else {
                                settings.defaultShoppingListId = id
                                settings.defaultShoppingListName = name
                            }
                        },
                    )
                    HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))
                    ToggleRow(
                        title = "Queue Items Locally",
                        checked = localGroceryList,
                        onCheckedChange = {
                            localGroceryList = it
                            settings.localGroceryList = it
                        },
                    )
                }
            }

            // Local mode info
            if (authState.isLocalMode) {
                SettingsSection(header = "Mode") {
                    ValueRow(title = "Mode", value = "Local")
                    HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))
                    ValueRow(title = "Recipes", value = "$localRecipeCount")
                }
            }

            if (authState.isServerConnected) {
                // Profile
                authState.currentUser?.let { user ->
                    SettingsSection(header = "Profile") {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(12.dp),
                            modifier = Modifier.fillMaxWidth().padding(16.dp),
                        ) {
                            Icon(
                                imageVector = Icons.Filled.AccountCircle,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.size(44.dp),
                            )
                            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                Text(
                                    text = user.fullName ?: user.username ?: "User",
                                    style = MaterialTheme.typography.titleMedium,
                                )
                                Text(
                                    text = user.email ?: "",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }
                    }
                }

                // Server info
                SettingsSection(header = "Server") {
                    ValueRow(
                        title = "URL",
                        value = container.authStore.savedServerURL ?: "Not connected",
                    )
                    authState.serverInfo?.let { info ->
                        HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))
                        ValueRow(title = "Version", value = "v${info.version}")
                    }
                    HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.fillMaxWidth().padding(16.dp),
                    ) {
                        Text(text = "Recipes Synced", modifier = Modifier.weight(1f))
                        if (isSyncing) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(6.dp),
                            ) {
                                Text(
                                    text = "Syncing...",
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                                CircularProgressIndicator(
                                    modifier = Modifier.size(16.dp),
                                    strokeWidth = 2.dp,
                                )
                            }
                        } else {
                            Text(
                                text = "$syncedCount",
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                }
            }

            // About
            SettingsSection(header = "About") {
                ValueRow(title = "App Version", value = com.jackabee.mealie.BuildConfig.VERSION_NAME)
                HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))
                ValueRow(title = "Built with", value = "Jetpack Compose")
            }

            // Actions
            SettingsSection {
                if (authState.isServerConnected) {
                    ActionRow(
                        title = "Refresh Profile",
                        icon = Icons.Filled.Refresh,
                        onClick = { scope.launch { authViewModel.loadCurrentUser() } },
                    )
                    HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))
                    ActionRow(
                        title = "Sign Out",
                        icon = Icons.AutoMirrored.Filled.Logout,
                        tint = MaterialTheme.colorScheme.error,
                        onClick = { showLogoutDialog = true },
                    )
                } else {
                    ActionRow(
                        title = "Connect to Server",
                        icon = Icons.Filled.Dns,
                        onClick = {
                            if (authState.isLocalMode) {
                                showLogoutDialog = true
                            } else {
                                authViewModel.showServerSetupForm()
                                showLoginDialog = true
                            }
                        },
                    )
                }
            }

            Spacer(modifier = Modifier.height(12.dp))
        }
    }

    if (showLogoutDialog) {
        AlertDialog(
            onDismissRequest = { showLogoutDialog = false },
            title = { Text(if (authState.isLocalMode) "Connect to Server" else "Sign Out") },
            text = {
                Text(
                    if (authState.isLocalMode) {
                        "Your local recipes will be preserved."
                    } else {
                        "Are you sure you want to sign out?"
                    }
                )
            },
            confirmButton = {
                if (authState.isLocalMode) {
                    TextButton(onClick = {
                        showLogoutDialog = false
                        authViewModel.showServerSetupForm()
                        showLoginDialog = true
                    }) {
                        Text("Continue")
                    }
                } else {
                    TextButton(onClick = {
                        showLogoutDialog = false
                        authViewModel.logout()
                    }) {
                        Text("Sign Out", color = MaterialTheme.colorScheme.error)
                    }
                }
            },
            dismissButton = {
                TextButton(onClick = { showLogoutDialog = false }) { Text("Cancel") }
            },
        )
    }

    if (showLoginDialog) {
        Dialog(
            onDismissRequest = { showLoginDialog = false },
            properties = DialogProperties(usePlatformDefaultWidth = false),
        ) {
            Surface(modifier = Modifier.fillMaxSize()) {
                Box(modifier = Modifier.fillMaxSize()) {
                    LoginScreen(authViewModel = authViewModel, hideLocalMode = true)
                    IconButton(
                        onClick = { showLoginDialog = false },
                        modifier = Modifier.align(Alignment.TopEnd).padding(8.dp),
                    ) {
                        Icon(imageVector = Icons.Filled.Close, contentDescription = "Close")
                    }
                }
            }
        }
    }
}

// MARK: Building blocks

@Composable
private fun SettingsSection(
    header: String? = null,
    footer: String? = null,
    content: @Composable () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        if (header != null) {
            Text(
                text = header,
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(start = 16.dp),
            )
        }
        Surface(
            shape = RoundedCornerShape(12.dp),
            color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Column { content() }
        }
        if (footer != null) {
            Text(
                text = footer,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 16.dp),
            )
        }
    }
}

@Composable
private fun ValueRow(title: String, value: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().padding(16.dp),
    ) {
        Text(text = title)
        Spacer(modifier = Modifier.weight(1f))
        Text(
            text = value,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(start = 16.dp),
        )
    }
}

@Composable
private fun ToggleRow(title: String, checked: Boolean, onCheckedChange: (Boolean) -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 6.dp),
    ) {
        Text(text = title, modifier = Modifier.weight(1f))
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}

@Composable
private fun ActionRow(
    title: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    tint: androidx.compose.ui.graphics.Color = MaterialTheme.colorScheme.primary,
    onClick: () -> Unit,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick).padding(16.dp),
    ) {
        Icon(imageVector = icon, contentDescription = null, tint = tint)
        Text(text = title, color = tint, fontWeight = FontWeight.Medium)
    }
}

@Composable
private fun DefaultListRow(
    selectedId: String,
    lists: List<Pair<String, String>>,
    onSelect: (id: String, name: String?) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    val selectedName = if (selectedId.isEmpty()) {
        "Ask Every Time"
    } else {
        lists.firstOrNull { it.first == selectedId }?.second
            ?: appContainer().settings.defaultShoppingListName
            ?: "Ask Every Time"
    }

    Box {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .clickable { expanded = true }
                .padding(16.dp),
        ) {
            Text(text = "Default Shopping List", modifier = Modifier.weight(1f))
            Text(
                text = selectedName,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(start = 16.dp),
            )
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            DropdownMenuItem(
                text = { Text("Ask Every Time") },
                onClick = {
                    expanded = false
                    onSelect("", null)
                },
            )
            lists.forEach { (id, name) ->
                DropdownMenuItem(
                    text = { Text(name) },
                    onClick = {
                        expanded = false
                        onSelect(id, name)
                    },
                )
            }
        }
    }
}
