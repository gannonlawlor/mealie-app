# Mealie Recipe Saver — Browser Extension

A Manifest V3 WebExtension that saves recipes from any website to your self-hosted
[Mealie](https://mealie.io) server. One shared vanilla-JS codebase runs in Chrome,
Firefox, and (via the generated wrapper app) Safari — no bundler, no npm dependencies.

## What it does

- **Detects recipes** on the page you are viewing by scanning schema.org `Recipe`
  JSON-LD (the same structured data Mealie's own scraper uses). A green check badge
  appears on the toolbar icon when a recipe is found.
- **Saves with one click** from the toolbar popup, or via the right-click context
  menu on any page or link ("Save recipe to Mealie"). The extension sends the URL to
  `POST /api/recipes/create/url` and your Mealie server does the scraping.
- **Notifies you** of success (with the new recipe slug) or failure.

Even when no recipe is detected, you can still hit Save — Mealie's server-side
scraper handles more formats (microdata, heuristics) than the extension checks for.

## Installation (load unpacked)

### Chrome / Edge / Brave

1. Open `chrome://extensions`.
2. Enable **Developer mode** (top-right toggle).
3. Click **Load unpacked** and select this `extension/` directory.

### Firefox

1. Open `about:debugging#/runtime/this-firefox`.
2. Click **Load Temporary Add-on…**.
3. Select `extension/manifest.json`.

Temporary add-ons are removed when Firefox restarts. For a persistent install,
package and sign the extension via [addons.mozilla.org](https://addons.mozilla.org)
(the `browser_specific_settings.gecko.id` is already set to
`mealie-saver@jackabee.com`).

### Safari (macOS)

Safari requires web extensions to ship inside a native wrapper app. A generated
Xcode project lives in `extension/safari/Mealie Saver/` (build artifacts are
git-ignored). To build and enable it:

```sh
xcodebuild -project "extension/safari/Mealie Saver/Mealie Saver.xcodeproj" \
  -scheme "Mealie Saver" build CODE_SIGN_IDENTITY=-
```

Then launch the built "Mealie Saver" app once, and enable the extension in
Safari → Settings → Extensions. Because the app is ad-hoc signed you may also need
Safari → Settings → Developer → **Allow unsigned extensions**.

To regenerate the wrapper from scratch (e.g. after Xcode updates), run the
converter against a copy of this directory that excludes `safari/` and `test/`
(the converter copies the extension resources into the project, so it must not
recurse into its own output):

```sh
rsync -a --exclude safari --exclude test extension/ /tmp/mealie-ext-src/
xcrun safari-web-extension-converter /tmp/mealie-ext-src \
  --project-location extension/safari \
  --app-name "Mealie Saver" --bundle-identifier com.jackabee.mealie.saver \
  --macos-only --copy-resources --no-open --no-prompt --force
```

Note: the converter sets the app target's bundle identifier to
`com.jackabee.mealie.Mealie-Saver`, which breaks the embedded-extension
validation (`com.jackabee.mealie.saver.Extension` is not prefixed by it). After
regenerating, set `PRODUCT_BUNDLE_IDENTIFIER = com.jackabee.mealie.saver` on the
app target in the pbxproj — the checked-in project already has this fix.

## Setup and authentication

Open the extension's options page and enter your Mealie **Server URL**, then either:

- **Email + password** — the extension calls `POST /api/auth/token` and stores the
  returned JWT. Your password is used once for that request and never stored.
  Mealie login JWTs **expire** (typically after 48 hours), after which you must
  sign in again; or
- **API token (recommended)** — create a long-lived token in Mealie under
  *User Profile → Manage Your API Tokens* and paste it in. It does not expire.

**Test connection** verifies the stored token against `/api/app/about` and
`/api/users/self` and reports the server version and signed-in user. **Sign out**
removes everything the extension stored (`serverUrl`, `token`, `email`, `savedAt`).

## Permissions rationale

| Permission | Why |
| --- | --- |
| `storage` | Persist the server URL and auth token locally. |
| `activeTab` | Read the current tab's URL/title when the popup saves it. |
| `contextMenus` | The right-click "Save recipe to Mealie" items. |
| `scripting` | MV3 companion to host access for content-script injection. |
| `notifications` | Success/failure toasts for context-menu saves (which have no popup UI). |
| `host_permissions: http://*/*, https://*/*` | Two reasons: (1) your Mealie server lives at an arbitrary self-hosted origin — often plain HTTP on a LAN — and the extension must be able to `fetch()` it without CORS failures; (2) the recipe-detection content script needs to run on whatever cooking site you visit. |

## Development

```
extension/
  manifest.json        MV3 manifest (Chrome service worker + Firefox event page)
  popup.html/.css      Toolbar popup
  options.html/.css    Settings page
  src/
    common.js          browser/chrome shim, storage + Mealie API helpers
    detect-core.js     Pure JSON-LD Recipe finder (shared with the test suite)
    detect.js          Content script: scans the page, badges + answers the popup
    background.js      Badge, context menus, notifications, saves
    popup.js           Popup logic
    options.js         Options logic
  icons/               16/32/48/128 px, derived from the Android launcher icon
  test/                node --test unit tests for detect-core.js
  safari/              Generated Safari wrapper Xcode project
```

Run the tests (requires Node 18+, no dependencies):

```sh
node --test extension/test/detect.test.mjs
```
