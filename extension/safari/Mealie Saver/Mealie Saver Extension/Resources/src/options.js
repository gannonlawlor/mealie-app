/*
 * options.js — settings page. Two ways to authenticate:
 *   1. Email + password → POST /api/auth/token, store the returned JWT.
 *      (Mealie login JWTs expire — the UI recommends option 2 for longevity.)
 *   2. A long-lived API token pasted from Mealie's profile settings.
 * Only serverUrl / token / email / savedAt are persisted. Never the password.
 */

"use strict";

(() => {
  const Common = globalThis.MealieCommon;

  const el = (id) => document.getElementById(id);
  const serverInput = el("server-url");
  const statusEl = el("status");
  const sectionConnected = el("section-connected");

  function showStatus(message, cls) {
    statusEl.hidden = false;
    statusEl.className = "status" + (cls ? " " + cls : "");
    statusEl.textContent = message;
  }

  function clearStatus() {
    statusEl.hidden = true;
    statusEl.textContent = "";
  }

  function requireServerUrl() {
    const url = Common.normalizeServerUrl(serverInput.value);
    if (!url) {
      showStatus("Enter your Mealie server URL first.", "err");
      serverInput.focus();
      return null;
    }
    serverInput.value = url;
    return url;
  }

  async function refreshConnectedView() {
    const settings = await Common.getSettings();
    if (settings.serverUrl) serverInput.value = settings.serverUrl;
    if (settings.email) el("email").value = settings.email;
    if (Common.isConfigured(settings)) {
      sectionConnected.hidden = false;
      const when = settings.savedAt ? new Date(settings.savedAt).toLocaleString() : "unknown";
      el("connected-as").textContent =
        "A token for " + settings.serverUrl +
        (settings.email ? " (" + settings.email + ")" : "") +
        " is stored (saved " + when + ").";
    } else {
      sectionConnected.hidden = true;
    }
    return settings;
  }

  async function storeToken(serverUrl, token, email) {
    await Common.saveSettings({
      serverUrl,
      token,
      email: email || "",
      savedAt: Date.now(),
    });
    await refreshConnectedView();
  }

  async function withBusy(button, busyLabel, fn) {
    const original = button.textContent;
    button.disabled = true;
    button.textContent = busyLabel;
    try {
      await fn();
    } finally {
      button.disabled = false;
      button.textContent = original;
    }
  }

  async function signIn() {
    clearStatus();
    const serverUrl = requireServerUrl();
    if (!serverUrl) return;
    const email = el("email").value.trim();
    const password = el("password").value;
    if (!email || !password) {
      showStatus("Enter your email and password.", "err");
      return;
    }
    await withBusy(el("btn-signin"), "Signing in…", async () => {
      try {
        const token = await Common.login(serverUrl, email, password);
        el("password").value = ""; // used once, never stored
        await storeToken(serverUrl, token, email);
        await testConnection(true);
      } catch (err) {
        console.error("Mealie Recipe Saver: sign-in failed", err);
        showStatus(err.message || "Sign-in failed.", "err");
      }
    });
  }

  async function useToken() {
    clearStatus();
    const serverUrl = requireServerUrl();
    if (!serverUrl) return;
    const token = el("api-token").value.trim();
    if (!token) {
      showStatus("Paste an API token first.", "err");
      return;
    }
    await withBusy(el("btn-use-token"), "Checking…", async () => {
      try {
        // Validate the token before storing it.
        const info = await Common.testConnection({ serverUrl, token });
        el("api-token").value = "";
        await storeToken(serverUrl, token, el("email").value.trim());
        showStatus("Connected to Mealie v" + info.version + " as " + info.userName, "ok");
      } catch (err) {
        console.error("Mealie Recipe Saver: token check failed", err);
        showStatus(err.message || "Token check failed.", "err");
      }
    });
  }

  async function testConnection(silentErrors) {
    clearStatus();
    const settings = await Common.getSettings();
    if (!Common.isConfigured(settings)) {
      showStatus("Not connected yet — sign in or paste an API token.", "err");
      return;
    }
    await withBusy(el("btn-test"), "Testing…", async () => {
      try {
        const info = await Common.testConnection(settings);
        showStatus("Connected to Mealie v" + info.version + " as " + info.userName, "ok");
      } catch (err) {
        console.error("Mealie Recipe Saver: connection test failed", err);
        if (!silentErrors) showStatus(err.message || "Connection test failed.", "err");
      }
    });
  }

  async function signOut() {
    clearStatus();
    await Common.clearSettings();
    el("password").value = "";
    el("api-token").value = "";
    await refreshConnectedView();
    showStatus("Signed out. Stored server settings were removed.", "ok");
  }

  document.addEventListener("DOMContentLoaded", async () => {
    el("btn-signin").addEventListener("click", signIn);
    el("btn-use-token").addEventListener("click", useToken);
    el("btn-test").addEventListener("click", () => testConnection(false));
    el("btn-signout").addEventListener("click", signOut);
    el("password").addEventListener("keydown", (e) => { if (e.key === "Enter") signIn(); });
    el("api-token").addEventListener("keydown", (e) => { if (e.key === "Enter") useToken(); });
    await refreshConnectedView();
  });
})();
