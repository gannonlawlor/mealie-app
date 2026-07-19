# SwiftUI View Behavioral Specs (for the Compose port)

_Generated from the Skip-era SwiftUI sources. Each section is the behavioral contract for the
equivalent Compose screen. See also `docs/ANALYSIS.md` for the feature inventory, and
`ios/Sources/MealieUI/Views/` for the original code._

## LoginView
Bound to AuthViewModel; param `hideLocalMode: Bool = false`.

- Root: scrollable centered column (spacing 24, horizontal padding 32).
- Header: fork/knife icon (size 72, accent), "Mealie" (large bold), "Your Recipe Manager" (secondary).
- Body switch: if `showServerSetup` show serverSetupForm, else loginForm.
- Error text: red caption centered below the form when `errorMessage` non-empty.
- serverSetupForm:
  - Heading "Connect to Server".
  - If savedServers non-empty: tappable server cards (server icon, URL with scheme stripped, email caption, chevron). Tap → selectSavedServer (fills URL+email, validates). Below: divider row "or enter a new server".
  - TextField "Server URL (e.g. mealie.example.com)", autocorrect off.
  - "Connect" button → validateServer(). Spinner while loading. Disabled when URL empty or loading.
  - If serverInfo set: green checkmark + "Connected - v{version}".
  - If !hideLocalMode: "or" divider, outlined accent button "Use Without Server" → enterLocalMode(), caption "Save recipes locally on your device. You can connect to a server later."
- loginForm:
  - Row: "Sign In" headline + "Change Server" button (back to server setup, clears error).
  - Email field, password field (secure). "Sign In" button → login(). Spinner while loading; disabled when either field empty.

## MealPlanView
- Column: ErrorBanner (dismissible) → weekHeader → scrollable day sections.
- weekHeader: left chevron (previousWeek+loadWeek), centered "MMM d - MMM d" title (weekStart..+6d), right chevron (nextWeek+loadWeek).
- Top bar: title "Meal Plan", "Today" action → goToThisWeek+loadWeek. Pull-to-refresh → loadWeek. Initial load on appear.
- daySection(date): header = day name (caption secondary) + day number (title bold; accent if today); trailing plus-circle button → open Add sheet for that date. Empty: "No meals planned". Else mealEntryRows.
- mealEntryRow: if entry has recipe with slug → navigates to RecipeDetail; else static. Trailing destructive xmark button → deleteMealPlan(id). Shows meal-type icon, meal type name (caption), displayTitle (1 line), chevron when navigable.
- Add sheet (AddMealPlanView): segmented meal-type picker (breakfast/lunch/dinner/snack, default dinner); search field (submit → search); list = searchResults if any else recipe list; row tap → addMealPlan(date, type, recipeId) + dismiss. Title "Add Meal - {dayName}". Search: if synced, filter local summary index by name contains; else API search perPage 20.

## ShoppingListsView (phone)
- ErrorBanner; list of shopping lists.
- Title "Shopping Lists"; plus action → "New Shopping List" alert/dialog: name field, Cancel, Create → createShoppingList. Message "Enter a name for the new shopping list."
- Rows: name (headline), "{uncheckedCount} items remaining" caption, green "{checkedCount} done" pill when >0. Tap → detail. Swipe-to-delete → deleteShoppingList.
- Pull-to-refresh; empty state "No shopping lists yet".

## ShoppingListDetailView
- Column: ErrorBanner → sync banner (green: checkmark + syncMessage + x to clear) → add-item bar (TextField "Add an item..." + plus button, disabled when empty → addItem) → list.
- List sections:
  - "Pending Upload" (if local pending items exist): orange up-arrow + note + trash (removePendingItem+refreshPendingCounts); upload button "Upload {n} items" (spinner + "Uploading..." while syncing) → syncPendingItems.
  - "To Buy" (unchecked), "Completed" (checked): row = tap toggles checked (toggleItem); leading green check-circle when checked else empty circle; displayText struck through + secondary when checked; note caption if item has food and note; trailing red trash → deleteItem.
  - All empty → "No items in this list".
- Title = list name. Toolbar upload action when pending items exist. Pull-to-refresh; initial: refreshPendingCounts + loadShoppingList.

## EditRecipeView
Form sheet, editable state populated from recipe (ingredients via displayText, instructions via text).
- Image section: current/selected image preview (height 150, rounded); photo picker "Change Image" → stores jpeg data for upload on save.
- Details: Name, Description, "Yield (e.g. 4 servings)". Times: Prep/Cook/Total text fields.
- Categories & Tags sections (when available): horizontal toggle chips (selected: accent bg/white text; else accent-12%/accent).
- Ingredients: text field per row + red minus remove; "Add Ingredient" appends empty. Instructions: numbered text fields + remove; "Add Step".
- Title "Edit Recipe". Cancel dismisses. Save (disabled when name empty or saving): builds note-only ingredients (isFood false, disableAmount true, display=text) + instructions from non-empty steps + selected category/tag objects, preserves untouched fields → updateRecipe; then uploadImage if new image picked; dismiss on success.

## RecipeDetailView
- States: loading spinner "Loading recipe..." / content / "Recipe not found".
- Top bar (inline title = recipe name): favorite heart (red filled when fav) → toggleFavorite; offline download button (server mode only; spinner while saving; green filled when saved) → toggleOffline; overflow menu: "Add to Meal Plan" (server only), "Edit Recipe", destructive "Delete Recipe".
- Delete confirm: "Are you sure you want to delete this recipe? This cannot be undone." → deleteRecipe; on success onDelete()+back.
- On appear: load detail (background-cache detail image in server mode); load shopping lists (server mode, if empty); keep screen awake while visible if setting enabled (release on exit).
- Content (scroll): hero image (h 250; local path → offline path → cached min-original → network URL; gray placeholder); title; description clamped to 3 lines with "Show more"/"Show less"; "View Original Recipe ↗" link when orgURL valid; time cards (Prep/Cook/Total/Yield; ISO8601 durations formatted "1h 30m"); category+tag chips; Ingredients section (header + "Long press to add" hint in server mode; optional bold section titles; bullet + displayText); Instructions (numbered accent circle badges, optional step titles); Nutrition 3-col grid of non-empty values.
- Ingredient long-press (server mode only): 0.5 s hold; accent-15% background fills proportionally left→right during hold (linear), eases back on cancel; haptic on success. On completion: if default shopping list set → add directly (locally-queued if localGroceryList setting else API; optionally Reminders on iOS); else open list-picker sheet.
- List-picker sheet "Add to Shopping List": rows = list name + "{n} pending" caption; tap adds (queued or API path) and closes. "No shopping lists found" if empty. Cancel clears selection.
- AddToMealPlanSheet: segmented meal-type picker (default dinner); 7 rows for today..+6 ("Today"/"Tomorrow"/weekday + "MMM d") with plus icon; tap → addMealPlan + dismiss. Title "Add to Meal Plan".

## RecipeSplitView (wide layout)
- Two panes: left 340dp list pane + divider + detail pane.
- Left: title "Recipes", search field (debounced + submit), filter chips row (categories with folder icon, tags with tag icon; tap toggles selection, same-tap clears, reload), matching-tag chips above list during search (tap → select tag, clear search, reload), recipe rows (Button setting selectedSlug; selected row bg accent-12%), swipe leading favorite / trailing delete + offline toggle, infinite-scroll trailing spinner row, pull-to-refresh, plus toolbar action → import sheet.
- Right: RecipeDetail for selection (keyed by slug; onDelete clears selection) or empty state (book glyph + "Select a recipe").

## ShoppingSplitView (wide layout)
- Same two-pane pattern: left list of shopping lists (selected bg accent-12%; delete clears selection if selected), right ShoppingListDetail or empty state (cart glyph + "Select a shopping list"). Plus action → same New List dialog.

## SidebarView (wide layout)
- 240dp column, sidebar bg.
- User header: server connected → person icon + fullName/username + email; local mode → drive icon + "Local Mode"/"Recipes saved on device"; else app icon + "Mealie"/"Connect to get started".
- Tab buttons: Recipes (book) always; Meal Plan (calendar) + Shopping (cart) only when server-connected; Settings (gear) always. Selected: accent-15% bg + accent tint.
- Footer: server connected → red "Sign Out" (confirm dialog "Are you sure you want to sign out?"); else "Connect to Server" (local mode first confirms "Your local recipes will be preserved." then opens login).
- Login opens as sheet (hideLocalMode when already in local mode); closes automatically when authenticated/connected.

## ErrorBanner
- Red (90%) rounded card: warning triangle + message (white, 2 lines) + [debug builds with detail: chevron toggle revealing detail caption] + x dismiss.

## AdaptiveColors → Compose mapping
Grayscale tokens by theme: field 0.15 dark/0.9 light; surface 0.18/0.9; sidebar 0.1/0.95; placeholder 0.2/0.85. In Compose use Material3 surfaceVariant/surfaceContainer equivalents rather than literal grays where it looks right; keep contrast semantics.

## Cross-cutting
- Local mode hides: offline save, add-to-meal-plan, Meal Plan + Shopping destinations, ingredient long-press-add.
- Accent at 12–15% opacity = standard chip/selected fill.
- RecipeListView (phone) additionally has: favorites-only heart toggle in top bar, import sheet (URL field + Import button + message; local mode adds "Create New Recipe" flow → name field → create → straight into editor; duplicate dialog "Recipe Already Exists" with Update Existing / Import Anyway / Cancel), matching-tag suggestions, swipe favorite/delete/offline actions, thumbnail rows (60dp rounded images, name, 2-line description, up to 3 category chips, offline badge, star rating).
