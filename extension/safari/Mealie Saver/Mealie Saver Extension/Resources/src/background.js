/*
 * background.js — MV3 background logic for Chrome (service worker) and Firefox
 * (event page). Responsibilities:
 *   - show a small green corner check when a page has a Recipe,
 *   - restore the normal icon on navigation,
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
// Chrome controls the native badge size. Draw a 6px corner check into the
// 16px toolbar icon instead, with matching assets for higher-density displays.
// ---------------------------------------------------------------------------

const ICON_PATHS = Object.fromEntries([16, 32, 48, 128].map((size) => [size, `icons/icon-${size}.png`]));
const detectedTabs = new Map();
let detectedIcons;

function getDetectedIcons() {
  if (!detectedIcons) {
    detectedIcons = Promise.all(Object.entries(ICON_PATHS).map(async ([size, path]) => {
      const pixels = Number(size);
      const response = await fetch(browserApi.runtime.getURL(path));
      if (!response.ok) throw new Error("Could not load toolbar icon: " + path);
      const bitmap = await createImageBitmap(await response.blob());
      const canvas = typeof OffscreenCanvas === "function"
        ? new OffscreenCanvas(pixels, pixels)
        : Object.assign(document.createElement("canvas"), { width: pixels, height: pixels });
      const ctx = canvas.getContext("2d");
      ctx.drawImage(bitmap, 0, 0, pixels, pixels);
      bitmap.close();
      ctx.scale(pixels / 16, pixels / 16);
      ctx.fillStyle = "#2E7D32";
      ctx.beginPath();
      ctx.arc(13, 13, 3, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = "#FFFFFF";
      ctx.lineWidth = 1;
      ctx.lineCap = "round";
      ctx.lineJoin = "round";
      ctx.beginPath();
      ctx.moveTo(11.5, 13);
      ctx.lineTo(12.5, 14);
      ctx.lineTo(14.5, 12);
      ctx.stroke();
      return [size, ctx.getImageData(0, 0, pixels, pixels)];
    })).then(Object.fromEntries).catch((err) => {
      detectedIcons = null; // A transient failure can be retried on the next page.
      throw err;
    });
  }
  return detectedIcons;
}

browserApi.runtime.onMessage.addListener((message, sender) => {
  if (message && message.type === "recipeDetected" && sender.tab && sender.tab.id != null) {
    const tabId = sender.tab.id;
    const detection = {};
    detectedTabs.set(tabId, detection);
    Promise.resolve(browserApi.action.setBadgeText({ tabId, text: "" })).catch(() => {});
    getDetectedIcons().then((imageData) => {
      // Don't restore a check after navigation or closure while images loaded.
      if (detectedTabs.get(tabId) === detection) {
        return browserApi.action.setIcon({ tabId, imageData });
      }
    }).catch((err) => console.error("Mealie Recipe Saver: detection icon failed", err));
  }
  // No async response needed for recipeDetected.
});

// Clear the indicator on navigation; the new page can set it again.
browserApi.tabs.onUpdated.addListener((tabId, changeInfo) => {
  if (changeInfo.status === "loading") {
    detectedTabs.delete(tabId);
    Promise.resolve(browserApi.action.setBadgeText({ tabId, text: "" })).catch(() => {});
    Promise.resolve(browserApi.action.setIcon({ tabId, path: ICON_PATHS })).catch(() => {});
  }
});
browserApi.tabs.onRemoved.addListener((tabId) => detectedTabs.delete(tabId));

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
