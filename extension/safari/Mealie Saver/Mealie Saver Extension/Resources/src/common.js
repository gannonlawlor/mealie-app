/*
 * common.js — shared helpers for every extension context (background, popup, options).
 *
 * Loaded as a classic (non-module) script so the same file works in:
 *   - the Chrome MV3 service worker (pulled in via importScripts from background.js)
 *   - the Firefox MV3 event page (listed before background.js in manifest "background.scripts")
 *   - popup.html / options.html (ordinary <script> tags)
 * Everything is exposed on globalThis.MealieCommon.
 *
 * Cross-browser notes:
 *   - Firefox exposes the promise-based `browser.*` namespace; Chrome exposes `chrome.*`.
 *     In Manifest V3 Chrome's chrome.* APIs return promises when no callback is passed
 *     (verified for storage.local.get/set/remove, tabs.query, tabs.sendMessage,
 *     action.setBadgeText, notifications.create — every async API used here), so a
 *     single `const api = browser ?? chrome` shim is enough; no callback wrappers needed.
 *   - contextMenus.create is the one exception: it returns the menu-item id
 *     synchronously in both browsers (optional callback in Chrome), so it is simply
 *     called without awaiting.
 *
 * Why the broad host permissions (http and https on all hosts) in manifest.json:
 *   1. The user's Mealie server lives at an arbitrary self-hosted origin (often plain
 *      http on a LAN), unknown at install time — fetch() from the extension needs a
 *      host permission for it to avoid CORS failures.
 *   2. The content script must run on every recipe site to detect schema.org/Recipe
 *      JSON-LD and light the toolbar badge.
 */

"use strict";

// Firefox: `browser` (promise-based). Chrome: `chrome` (promise-based in MV3).
const api = globalThis.browser ?? globalThis.chrome;

const MealieCommon = {
  api,

  STORAGE_KEYS: ["serverUrl", "token", "email", "savedAt"],

  /** Trim whitespace and trailing slashes; prepend https:// when no scheme given. */
  normalizeServerUrl(raw) {
    let url = (raw || "").trim();
    if (!url) return "";
    if (!/^https?:\/\//i.test(url)) url = "https://" + url;
    return url.replace(/\/+$/, "");
  },

  /** Read stored settings: { serverUrl, token, email, savedAt }. */
  async getSettings() {
    return api.storage.local.get(MealieCommon.STORAGE_KEYS);
  },

  /** Persist a partial settings object. The password is never stored. */
  async saveSettings(partial) {
    return api.storage.local.set(partial);
  },

  /** Remove all stored settings (sign out). */
  async clearSettings() {
    return api.storage.local.remove(MealieCommon.STORAGE_KEYS);
  },

  /** True when both a server URL and a token are stored. */
  isConfigured(settings) {
    return Boolean(settings && settings.serverUrl && settings.token);
  },

  /**
   * fetch() against the Mealie server with Bearer auth.
   * Returns the parsed JSON body; throws MealieApiError on non-2xx.
   */
  async mealieFetch(settings, path, options = {}) {
    const url = settings.serverUrl + path;
    const headers = Object.assign(
      {
        Accept: "application/json",
        Authorization: "Bearer " + settings.token,
      },
      options.headers || {}
    );
    let response;
    try {
      response = await fetch(url, Object.assign({}, options, { headers }));
    } catch (err) {
      throw MealieCommon.apiError(0, "Could not reach " + settings.serverUrl + " — " + err.message);
    }
    if (!response.ok) {
      let detail = "";
      try {
        detail = await response.text();
      } catch (_) {
        /* body unavailable; status alone is enough */
      }
      throw MealieCommon.apiError(response.status, detail);
    }
    // Some endpoints (e.g. create/url) return a bare JSON string; response.json()
    // handles both objects and strings.
    return response.json();
  },

  /** Build an Error carrying the HTTP status for callers to branch on (401 etc.). */
  apiError(status, detail) {
    const messages = {
      0: detail || "Network error",
      401: "Not authorized. Your session may have expired — sign in again in the extension options.",
    };
    const err = new Error(messages[status] || "Mealie server returned HTTP " + status + (detail ? ": " + String(detail).slice(0, 200) : ""));
    err.status = status;
    return err;
  },

  /**
   * POST /api/recipes/create/url — asks the Mealie server to scrape `pageUrl`.
   * The response body is a bare JSON-encoded string containing the new recipe slug.
   */
  async createRecipeFromUrl(settings, pageUrl) {
    const slug = await MealieCommon.mealieFetch(settings, "/api/recipes/create/url", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ url: pageUrl, includeTags: true }),
    });
    return typeof slug === "string" ? slug : String(slug);
  },

  /**
   * POST /api/auth/token — form-encoded login. Response uses snake_case
   * ({"access_token","token_type"}), unlike the rest of the API.
   * Returns the access token; the password is used once and discarded.
   */
  async login(serverUrl, email, password) {
    const body = new URLSearchParams({ username: email, password }).toString();
    let response;
    try {
      response = await fetch(serverUrl + "/api/auth/token", {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          Accept: "application/json",
        },
        body,
      });
    } catch (err) {
      throw MealieCommon.apiError(0, "Could not reach " + serverUrl + " — " + err.message);
    }
    if (response.status === 401 || response.status === 403) {
      throw new Error("Sign-in failed: wrong email or password.");
    }
    if (!response.ok) {
      throw MealieCommon.apiError(response.status, await response.text().catch(() => ""));
    }
    const json = await response.json();
    if (!json.access_token) throw new Error("Sign-in failed: server did not return a token.");
    return json.access_token;
  },

  /**
   * Verify a serverUrl+token pair: GET /api/app/about (version) and
   * /api/users/self (camelCase user object). Returns { version, userName }.
   */
  async testConnection(settings) {
    const about = await MealieCommon.mealieFetch(settings, "/api/app/about");
    const user = await MealieCommon.mealieFetch(settings, "/api/users/self");
    return {
      version: about.version || "unknown",
      userName: user.fullName || user.username || user.email || "unknown user",
    };
  },
};

globalThis.MealieCommon = MealieCommon;
