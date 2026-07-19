/*
 * detect.js — content script (runs on every http/https page, top frame only).
 *
 * Scans <script type="application/ld+json"> blocks for a schema.org Recipe using
 * the pure logic in detect-core.js (loaded just before this file, exposed as
 * globalThis.MealieDetect). On a hit it notifies the background script so the
 * toolbar badge lights up, and it answers "queryRecipe" messages from the popup.
 */

"use strict";

(() => {
  const api = globalThis.browser ?? globalThis.chrome;

  /** Detection result for this page: { name, image } or null. */
  let detected = null;

  function collectJsonLdTexts() {
    // CSS attribute match is case-sensitive; select all scripts with a type
    // attribute and filter case-insensitively to catch "application/LD+JSON" etc.
    const scripts = document.querySelectorAll("script[type]");
    const texts = [];
    for (const s of scripts) {
      if ((s.getAttribute("type") || "").toLowerCase().trim() === "application/ld+json") {
        texts.push(s.textContent || "");
      }
    }
    return texts;
  }

  function runDetection() {
    try {
      detected = globalThis.MealieDetect.findRecipeInBlocks(collectJsonLdTexts());
    } catch (err) {
      // Never let detection break the host page; just log and treat as no recipe.
      console.debug("Mealie Recipe Saver: detection error", err);
      detected = null;
    }
    if (detected) {
      // Fire-and-forget; the background may be asleep on Firefox event pages,
      // which wakes it. Catch to avoid unhandled rejections on chrome-restricted pages.
      Promise.resolve(
        api.runtime.sendMessage({ type: "recipeDetected", name: detected.name })
      ).catch(() => {});
    }
  }

  // The popup asks for the current detection result when it opens.
  api.runtime.onMessage.addListener((message, _sender, sendResponse) => {
    if (message && message.type === "queryRecipe") {
      sendResponse({ detected });
    }
    // Synchronous response; returning nothing closes the channel immediately.
  });

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", runDetection, { once: true });
  } else {
    runDetection();
  }
})();
