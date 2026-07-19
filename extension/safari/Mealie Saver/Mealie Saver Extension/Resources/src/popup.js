/*
 * popup.js — toolbar popup. Shows setup prompt when unconfigured; otherwise the
 * current tab, the content script's detection result, and a Save button that
 * POSTs the tab URL to /api/recipes/create/url.
 */

"use strict";

(() => {
  const Common = globalThis.MealieCommon;
  const api = Common.api;

  const el = (id) => document.getElementById(id);
  const viewSetup = el("view-setup");
  const viewMain = el("view-main");
  const saveBtn = el("btn-save");
  const saveStatus = el("save-status");
  const detectStatus = el("detect-status");

  let currentTab = null;
  let settings = null;

  function openOptions() {
    api.runtime.openOptionsPage();
    window.close();
  }

  function showSaveStatus(html, cls) {
    saveStatus.hidden = false;
    saveStatus.className = "save-status" + (cls ? " " + cls : "");
    saveStatus.innerHTML = html;
  }

  function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, (c) => ({
      "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
    }[c]));
  }

  async function queryDetection(tabId) {
    // The content script may not exist on this page (chrome://, PDFs, the web
    // store, pages loaded before install) — treat any failure as "no recipe".
    try {
      const reply = await api.tabs.sendMessage(tabId, { type: "queryRecipe" });
      return reply && reply.detected ? reply.detected : null;
    } catch (_) {
      return null;
    }
  }

  async function save() {
    saveBtn.disabled = true;
    saveBtn.textContent = "Saving…";
    saveStatus.hidden = true;

    try {
      const slug = await Common.createRecipeFromUrl(settings, currentTab.url);
      saveBtn.textContent = "Saved!";
      // Where to link after a save: the recipe page path varies across Mealie
      // versions ("/g/{group}/r/{slug}" on current releases, "/recipe/{slug}"
      // historically), and the group slug is unknown here. The reliable choice
      // is to link to the server root — every Mealie version lands the user in
      // their recipe list — and surface the new slug as text.
      showSaveStatus(
        'Saved! Recipe slug: <strong>' + escapeHtml(slug) + "</strong><br>" +
          '<a href="' + escapeHtml(settings.serverUrl) + '" target="_blank" rel="noopener">Open Mealie</a>',
        "ok"
      );
    } catch (err) {
      console.error("Mealie Recipe Saver: save failed", err);
      saveBtn.disabled = false;
      saveBtn.textContent = "Save to Mealie";
      if (err.status === 401) {
        showSaveStatus(
          'Your session has expired. <a href="#" id="link-signin">Sign in again</a> in the options.',
          "err"
        );
        const link = el("link-signin");
        if (link) link.addEventListener("click", (e) => { e.preventDefault(); openOptions(); });
      } else {
        showSaveStatus(escapeHtml(err.message || "Something went wrong."), "err");
      }
    }
  }

  async function init() {
    el("btn-open-options").addEventListener("click", openOptions);
    el("link-options").addEventListener("click", (e) => { e.preventDefault(); openOptions(); });
    saveBtn.addEventListener("click", save);

    settings = await Common.getSettings();
    if (!Common.isConfigured(settings)) {
      viewSetup.hidden = false;
      return;
    }
    viewMain.hidden = false;

    const tabs = await api.tabs.query({ active: true, currentWindow: true });
    currentTab = tabs && tabs[0];
    if (!currentTab || !/^https?:\/\//i.test(currentTab.url || "")) {
      el("page-title").textContent = currentTab ? (currentTab.title || "This page") : "No active tab";
      el("page-url").textContent = currentTab ? (currentTab.url || "") : "";
      detectStatus.textContent = "This page cannot be saved to Mealie.";
      saveBtn.disabled = true;
      return;
    }

    el("page-title").textContent = currentTab.title || currentTab.url;
    el("page-url").textContent = currentTab.url;

    const detected = await queryDetection(currentTab.id);
    if (detected && detected.name) {
      detectStatus.textContent = "Recipe detected: " + detected.name;
      detectStatus.classList.add("found");
    } else if (detected) {
      detectStatus.textContent = "Recipe detected on this page";
      detectStatus.classList.add("found");
    } else {
      detectStatus.textContent = "No recipe detected — Mealie will still try this URL";
    }
  }

  document.addEventListener("DOMContentLoaded", init);
})();
