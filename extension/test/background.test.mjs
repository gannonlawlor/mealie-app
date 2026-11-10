import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';

const source = await readFile(new URL('../src/background.js', import.meta.url), 'utf8');
const flush = () => new Promise((resolve) => setImmediate(resolve));

function background() {
  const events = {};
  const icons = [];
  const badges = [];
  const event = (name) => ({ addListener: (fn) => { events[name] = fn; } });
  let release;
  const ready = new Promise((resolve) => { release = resolve; });
  const api = {
    runtime: { onMessage: event('detect'), onInstalled: event('install'), getURL: (path) => path },
    tabs: { onUpdated: event('navigate'), onRemoved: event('close') },
    contextMenus: { onClicked: event('menu') },
    action: {
      setIcon: async (icon) => { icons.push(icon); },
      setBadgeText: async (badge) => { badges.push(badge); },
    },
  };
  class Canvas {
    constructor(width, height) { this.width = width; this.height = height; }
    getContext() {
      return {
        drawImage() {}, scale() {}, beginPath() {}, arc() {}, fill() {},
        moveTo() {}, lineTo() {}, stroke() {},
        getImageData: () => ({ width: this.width, height: this.height }),
      };
    }
  }
  vm.runInNewContext(source, {
    MealieCommon: { api }, console,
    fetch: async () => { await ready; return { ok: true, blob: async () => ({}) }; },
    createImageBitmap: async () => ({ close() {} }), OffscreenCanvas: Canvas,
  });
  return { events, icons, badges, release };
}

test('detection uses tab-specific icons instead of the native text badge', async () => {
  const app = background();
  app.events.detect({ type: 'recipeDetected' }, { tab: { id: 7 } });
  app.release();
  await flush();
  assert.equal(app.icons.length, 1);
  assert.equal(app.icons[0].tabId, 7);
  assert.deepEqual(Object.keys(app.icons[0].imageData), ['16', '32', '48', '128']);
  assert.ok(app.badges.every(({ text }) => text === ''));
});

test('navigation cannot be overwritten by a detection still loading its icons', async () => {
  const app = background();
  app.events.detect({ type: 'recipeDetected' }, { tab: { id: 7 } });
  app.events.navigate(7, { status: 'loading' });
  app.release();
  await flush();
  assert.equal(app.icons.length, 1);
  assert.equal(app.icons[0].path[16], 'icons/icon-16.png');
  assert.equal(app.icons[0].imageData, undefined);
});

test('closing a tab cancels its pending detection icon', async () => {
  const app = background();
  app.events.detect({ type: 'recipeDetected' }, { tab: { id: 7 } });
  app.events.close(7);
  app.release();
  await flush();
  assert.equal(app.icons.length, 0);
});

test('navigating one tab does not clear detection in another tab', async () => {
  const app = background();
  app.events.detect({ type: 'recipeDetected' }, { tab: { id: 7 } });
  app.events.detect({ type: 'recipeDetected' }, { tab: { id: 8 } });
  app.events.navigate(7, { status: 'loading' });
  app.release();
  await flush();
  assert.deepEqual(app.icons.filter((icon) => icon.imageData).map((icon) => icon.tabId), [8]);
});
