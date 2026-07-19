/*
 * detect-core.js — pure schema.org/Recipe JSON-LD detection logic.
 *
 * No DOM and no browser APIs here so the exact same file can be:
 *   - loaded as a classic content script (listed before detect.js in the manifest),
 *   - imported by the node --test suite (extension/test/detect.test.mjs).
 * Mechanism: this is a plain script with no import/export syntax that publishes its
 * API on globalThis.MealieDetect. In the browser, content scripts share one isolated
 * world so detect.js reads the global. Under Node, dynamic `import()` of an
 * extension-less-of-modules .js file evaluates it as CommonJS, which still assigns to
 * globalThis — the test then reads globalThis.MealieDetect. One source file, zero
 * duplication, no bundler.
 *
 * The search strategy mirrors RecipeUrlParser.findRecipe in the Android app
 * (android/app/src/main/java/com/jackabee/mealie/data/parser/RecipeUrlParser.kt)
 * and RecipeURLParser.swift on iOS: a JSON-LD block may be
 *   - a Recipe object itself ("@type": "Recipe" or ["Recipe", ...]),
 *   - an object with an "@graph" array containing the Recipe,
 *   - a top-level array of objects,
 * nested arbitrarily; the first Recipe found wins.
 */

"use strict";

const MealieDetect = {
  /** True when the object's @type is "Recipe" (string) or includes it (array). */
  isRecipeType(obj) {
    if (!obj || typeof obj !== "object" || Array.isArray(obj)) return false;
    const type = obj["@type"];
    if (typeof type === "string") return type === "Recipe";
    if (Array.isArray(type)) return type.includes("Recipe");
    return false;
  },

  /** JSON-LD `image` can be a string, an ImageObject, or an array of either. */
  extractImageUrl(value) {
    if (typeof value === "string") return value;
    if (Array.isArray(value)) return value.length ? MealieDetect.extractImageUrl(value[0]) : null;
    if (value && typeof value === "object" && typeof value.url === "string") return value.url;
    return null;
  },

  /**
   * Recursively search parsed JSON-LD for a Recipe node.
   * Returns { name, image } or null.
   */
  findRecipe(json) {
    if (json === null || typeof json !== "object") return null;

    if (Array.isArray(json)) {
      for (const item of json) {
        const found = MealieDetect.findRecipe(item);
        if (found) return found;
      }
      return null;
    }

    if (MealieDetect.isRecipeType(json)) {
      return {
        name: typeof json.name === "string" && json.name.trim() ? json.name.trim() : null,
        image: MealieDetect.extractImageUrl(json.image),
      };
    }

    if (Array.isArray(json["@graph"])) {
      for (const item of json["@graph"]) {
        const found = MealieDetect.findRecipe(item);
        if (found) return found;
      }
    }

    return null;
  },

  /**
   * Given the raw text of every <script type="application/ld+json"> block on a
   * page, parse each (skipping malformed JSON) and return the first Recipe found.
   */
  findRecipeInBlocks(blockTexts) {
    for (const text of blockTexts || []) {
      if (typeof text !== "string" || !text.trim()) continue;
      let parsed;
      try {
        parsed = JSON.parse(text);
      } catch (_) {
        continue; // malformed JSON-LD is common in the wild; ignore and move on
      }
      const found = MealieDetect.findRecipe(parsed);
      if (found) return found;
    }
    return null;
  },
};

globalThis.MealieDetect = MealieDetect;
