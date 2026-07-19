/*
 * background.js — MV3 background logic for Chrome (service worker) and Firefox
 * (event page). Responsibilities:
 *   - light a green check badge on the toolbar icon when a page has a Recipe,
 *   - clear the badge on navigation,
 *   - "Save recipe to Mealie" context menu on pages and links,
 *   - system notifications for save success / failure / auth problems.
 *
 * In Chrome this file runs as a service worker, so common.js is pulled in with
 * importScripts(). In Firefox the manifest "background.scripts" array already
 * loads common.js first and importScripts does not exist in an event page,
 * hence the guard.
 */

"use strict";

if (typeof importScripts === "function" && !globalThis.MealieCommon) {
  importScripts("common.js");
}

const { api: browserApi } = globalThis.MealieCommon;
const Common = globalThis.MealieCommon;

const MENU_SAVE_PAGE = "mealie-save-page";
const MENU_SAVE_LINK = "mealie-save-link";

// ---------------------------------------------------------------------------
// Badge: green check while the current page has a detected recipe.
// ---------------------------------------------------------------------------

browserApi.runtime.onMessage.addListener((message, sender) => {
  if (message && message.type === "recipeDetected" && sender.tab && sender.tab.id != null) {
    const tabId = sender.tab.id;
    Promise.resolve(browserApi.action.setBadgeText({ tabId, text: "✓" })).catch(() => {});
    Promise.resolve(browserApi.action.setBadgeBackgroundColor({ tabId, color: "#2E7D32" })).catch(() => {});
  }
  // No async response needed for recipeDetected.
});

// Clear the badge as soon as a tab starts loading a new document; the content
// script on the new page will re-set it if a recipe is found.
browserApi.tabs.onUpdated.addListener((tabId, changeInfo) => {
  if (changeInfo.status === "loading") {
    Promise.resolve(browserApi.action.setBadgeText({ tabId, text: "" })).catch(() => {});
  }
});

// ---------------------------------------------------------------------------
// Context menus
// ---------------------------------------------------------------------------

browserApi.runtime.onInstalled.addListener(() => {
  // removeAll first so reinstalls/updates don't throw duplicate-id errors.
  browserApi.contextMenus.removeAll(() => {
    // contextMenus.create returns the id synchronously in both browsers; the
    // Chrome-style callback form is accepted by Firefox too.
    browserApi.contextMenus.create({
      id: MENU_SAVE_PAGE,
      title: "Save recipe to Mealie",
      contexts: ["page"],
    });
    browserApi.contextMenus.create({
      id: MENU_SAVE_LINK,
      title: "Save linked recipe to Mealie",
      contexts: ["link"],
    });
  });
});

browserApi.contextMenus.onClicked.addListener((info) => {
  let url = null;
  if (info.menuItemId === MENU_SAVE_LINK) url = info.linkUrl;
  else if (info.menuItemId === MENU_SAVE_PAGE) url = info.pageUrl;
  if (url) saveUrlWithNotification(url);
});

// ---------------------------------------------------------------------------
// Saving + notifications
// ---------------------------------------------------------------------------

async function saveUrlWithNotification(url) {
  if (!/^https?:\/\//i.test(url || "")) {
    notify("Cannot save this page", "Only http(s) pages can be sent to Mealie.");
    return;
  }

  const settings = await Common.getSettings();
  if (!Common.isConfigured(settings)) {
    notify(
      "Mealie is not set up yet",
      "Open the extension options to enter your server address and sign in."
    );
    return;
  }

  try {
    const slug = await Common.createRecipeFromUrl(settings, url);
    notify("Saved to Mealie", "Saved: " + (slug || url));
  } catch (err) {
    console.error("Mealie Recipe Saver: save failed for", url, err);
    if (err.status === 401) {
      notify(
        "Mealie sign-in expired",
        "Your token was rejected (HTTP 401). Open the extension options and sign in again."
      );
    } else {
      notify("Could not save recipe", err.message || "Unknown error.");
    }
  }
}

function notify(title, message) {
  Promise.resolve(
    browserApi.notifications.create({
      type: "basic",
      iconUrl: browserApi.runtime.getURL("icons/icon-128.png"),
      title,
      message,
    })
  ).catch((err) => console.error("Mealie Recipe Saver: notification failed", err));
}
