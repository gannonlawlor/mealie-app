/*
 * detect.test.mjs — unit tests for the pure JSON-LD Recipe finder.
 * Run with:  node --test extension/test/detect.test.mjs
 *
 * detect-core.js is a classic (non-module) script that publishes its API on
 * globalThis.MealieDetect so it can double as a browser content script. Node
 * evaluates it as CommonJS via dynamic import (no import/export syntax inside),
 * after which we read the global — the exact same code path the browser uses.
 */

import { test } from "node:test";
import assert from "node:assert/strict";

await import("../src/detect-core.js");
const Detect = globalThis.MealieDetect;

test("detect-core registers its API on globalThis", () => {
  assert.ok(Detect, "globalThis.MealieDetect should be defined");
  assert.equal(typeof Detect.findRecipeInBlocks, "function");
});

test("plain Recipe object", () => {
  const block = JSON.stringify({
    "@context": "https://schema.org",
    "@type": "Recipe",
    name: "Weeknight Bolognese",
    image: "https://example.com/bolognese.jpg",
  });
  const found = Detect.findRecipeInBlocks([block]);
  assert.deepEqual(found, {
    name: "Weeknight Bolognese",
    image: "https://example.com/bolognese.jpg",
  });
});

test("Recipe nested in @graph", () => {
  const block = JSON.stringify({
    "@context": "https://schema.org",
    "@graph": [
      { "@type": "WebSite", name: "Example Cooking" },
      { "@type": "WebPage", name: "A page" },
      {
        "@type": "Recipe",
        name: "Graph Granola",
        image: { "@type": "ImageObject", url: "https://example.com/granola.png" },
      },
    ],
  });
  const found = Detect.findRecipeInBlocks([block]);
  assert.equal(found.name, "Graph Granola");
  assert.equal(found.image, "https://example.com/granola.png");
});

test("top-level array of JSON-LD objects", () => {
  const block = JSON.stringify([
    { "@type": "BreadcrumbList", itemListElement: [] },
    { "@type": "Recipe", name: "Array Arrabbiata", image: ["https://example.com/a.jpg", "https://example.com/b.jpg"] },
  ]);
  const found = Detect.findRecipeInBlocks([block]);
  assert.equal(found.name, "Array Arrabbiata");
  assert.equal(found.image, "https://example.com/a.jpg", "first image of an array wins");
});

test("@type given as an array", () => {
  const block = JSON.stringify({
    "@type": ["Recipe", "NewsArticle"],
    name: "Type-Array Tagine",
  });
  const found = Detect.findRecipeInBlocks([block]);
  assert.equal(found.name, "Type-Array Tagine");
  assert.equal(found.image, null);
});

test("malformed JSON block is skipped, later valid block still found", () => {
  const blocks = [
    '{"@type": "Recipe", "name": "Broken JSON",', // truncated on purpose
    JSON.stringify({ "@type": "Recipe", name: "Survivor Soup" }),
  ];
  const found = Detect.findRecipeInBlocks(blocks);
  assert.equal(found.name, "Survivor Soup");
});

test("no recipe anywhere returns null", () => {
  const blocks = [
    JSON.stringify({ "@type": "WebSite", name: "Not a recipe" }),
    JSON.stringify([{ "@type": "Organization" }]),
    "not json at all",
    "",
  ];
  assert.equal(Detect.findRecipeInBlocks(blocks), null);
});

test("recipe with missing name yields name null", () => {
  const block = JSON.stringify({ "@type": "Recipe", image: "https://example.com/x.jpg" });
  const found = Detect.findRecipeInBlocks([block]);
  assert.equal(found.name, null);
  assert.equal(found.image, "https://example.com/x.jpg");
});

test("deeply nested arrays inside @graph", () => {
  const block = JSON.stringify({
    "@graph": [[{ "@type": "Thing" }], [{ "@type": ["Recipe"], name: "Nested Nachos" }]],
  });
  const found = Detect.findRecipeInBlocks([block]);
  assert.equal(found.name, "Nested Nachos");
});
