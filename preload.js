'use strict';

/**
 * preload.js
 *
 * Runs in an isolated context (contextIsolation: true).
 * Only the explicitly listed methods are exposed to the renderer —
 * the full Node.js / Electron API is NOT accessible from index.html.
 */

const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('androidHelper', {
  // ── Outbound (renderer → main) ──────────────────────────────────────────

  /** Trigger the ADB device status check script */
  checkDevice: () => ipcRenderer.send('device:check'),

  /** Open the file picker and trigger the flash script */
  flashBoot: () => ipcRenderer.send('device:flash'),

  /** Ask the main process to clear the terminal */
  clearTerminal: () => ipcRenderer.send('terminal:clear'),

  // ── Inbound (main → renderer) ────────────────────────────────────────────

  /**
   * Subscribe to streamed terminal lines.
   * @param {function({ level: string, text: string }): void} callback
   * @returns {function} unsubscribe function
   */
  onTerminalLine: (callback) => {
    const handler = (_event, payload) => callback(payload);
    ipcRenderer.on('terminal:line', handler);
    // Return a function the renderer can call to stop listening
    return () => ipcRenderer.removeListener('terminal:line', handler);
  },

  /** Subscribe to terminal clear events */
  onTerminalClear: (callback) => {
    const handler = () => callback();
    ipcRenderer.on('terminal:clear', handler);
    return () => ipcRenderer.removeListener('terminal:clear', handler);
  },

  /** Subscribe to device-check completion */
  onCheckDone: (callback) => {
    const handler = (_event, payload) => callback(payload);
    ipcRenderer.on('device:check:done', handler);
    return () => ipcRenderer.removeListener('device:check:done', handler);
  },

  /** Subscribe to flash completion */
  onFlashDone: (callback) => {
    const handler = (_event, payload) => callback(payload);
    ipcRenderer.on('device:flash:done', handler);
    return () => ipcRenderer.removeListener('device:flash:done', handler);
  },
});
