'use strict';

/**
 * renderer.js
 *
 * Runs in the renderer process (browser context).
 * Communicates with the main process exclusively through
 * the contextBridge API exposed by preload.js as window.androidHelper.
 */

// ---------------------------------------------------------------------------
// DOM refs
// ---------------------------------------------------------------------------
const terminal        = document.getElementById('terminal');
const terminalEmpty   = document.getElementById('terminalEmpty');
const btnCheck        = document.getElementById('btnCheck');
const btnFlash        = document.getElementById('btnFlash');
const btnClear        = document.getElementById('btnClear');
const btnScrollBottom = document.getElementById('btnScrollBottom');
const statusDot       = document.getElementById('statusDot');
const statusText      = document.getElementById('statusText');

// Track whether any operation is running so we can lock the UI
let isRunning = false;

// ---------------------------------------------------------------------------
// Status helpers
// ---------------------------------------------------------------------------

function setStatus(state, message) {
  statusDot.className = `status-dot ${state}`;
  statusText.textContent = message;
}

function setRunning(running) {
  isRunning = running;
  btnCheck.disabled = running;
  btnFlash.disabled = running;

  if (running) {
    setStatus('running', 'Operation in progress…');
  }
}

function setButtonLoading(btn, loading) {
  if (loading) {
    btn.classList.add('loading');
    btn.disabled = true;
  } else {
    btn.classList.remove('loading');
    btn.disabled = false;
  }
}

// ---------------------------------------------------------------------------
// Terminal helpers
// ---------------------------------------------------------------------------

/**
 * Append a line to the terminal with appropriate styling.
 * @param {string} level - 'info' | 'success' | 'error' | 'warn'
 * @param {string} text  - the text to display
 */
function appendLine(level, text) {
  // Hide the "no output yet" placeholder
  if (terminalEmpty) terminalEmpty.style.display = 'none';

  const line = document.createElement('div');
  line.className = `t-line t-${level}`;

  const prefix = document.createElement('span');
  prefix.className = 'prefix';
  prefix.textContent = getPrefix(level);

  const textSpan = document.createElement('span');
  textSpan.className = 'text';
  textSpan.textContent = text;

  line.appendChild(prefix);
  line.appendChild(textSpan);
  terminal.appendChild(line);

  // Auto-scroll to bottom so the user always sees the latest output
  scrollToBottom();
}

function getPrefix(level) {
  switch (level) {
    case 'success': return '✔';
    case 'error':   return '✘';
    case 'warn':    return '⚠';
    default:        return '›';
  }
}

function scrollToBottom() {
  terminal.scrollTop = terminal.scrollHeight;
}

function clearTerminal() {
  // Remove all child nodes except the empty placeholder
  while (terminal.firstChild) {
    terminal.removeChild(terminal.firstChild);
  }
  terminal.appendChild(terminalEmpty);
  terminalEmpty.style.display = '';
}

// ---------------------------------------------------------------------------
// Subscribe to IPC events from the main process
// ---------------------------------------------------------------------------

// Stream terminal lines
window.androidHelper.onTerminalLine(({ level, text }) => {
  appendLine(level, text);
});

// Clear event
window.androidHelper.onTerminalClear(() => {
  clearTerminal();
});

// Device check finished
window.androidHelper.onCheckDone(({ code }) => {
  setButtonLoading(btnCheck, false);
  setRunning(false);

  if (code === 0) {
    setStatus('success', 'Device check completed successfully.');
  } else {
    setStatus('error', `Device check exited with code ${code}.`);
  }
});

// Flash finished
window.androidHelper.onFlashDone(({ code }) => {
  setButtonLoading(btnFlash, false);
  setRunning(false);

  if (code === 0) {
    setStatus('success', 'Boot image flashed. Device is rebooting.');
  } else if (code === -1) {
    setStatus('idle', 'File selection cancelled.');
  } else {
    setStatus('error', `Flash failed with exit code ${code}.`);
  }
});

// ---------------------------------------------------------------------------
// Button click handlers
// ---------------------------------------------------------------------------

btnCheck.addEventListener('click', () => {
  if (isRunning) return;
  setRunning(true);
  setButtonLoading(btnCheck, true);
  appendLine('info', '▶ Starting device check…');
  window.androidHelper.checkDevice();
});

btnFlash.addEventListener('click', () => {
  if (isRunning) return;
  setRunning(true);
  setButtonLoading(btnFlash, true);
  appendLine('info', '▶ Opening file picker…');
  window.androidHelper.flashBoot();
});

btnClear.addEventListener('click', () => {
  clearTerminal();
  if (!isRunning) setStatus('idle', 'Ready — connect your Android device via USB');
});

btnScrollBottom.addEventListener('click', () => {
  scrollToBottom();
});

// ---------------------------------------------------------------------------
// Keyboard shortcuts
// ---------------------------------------------------------------------------
document.addEventListener('keydown', (e) => {
  // Ctrl+L / Cmd+L → clear terminal
  if ((e.ctrlKey || e.metaKey) && e.key === 'l') {
    e.preventDefault();
    clearTerminal();
  }
  // End key → scroll to bottom
  if (e.key === 'End') {
    scrollToBottom();
  }
});

// ---------------------------------------------------------------------------
// Initial log entry
// ---------------------------------------------------------------------------
window.addEventListener('DOMContentLoaded', () => {
  // Nothing to do here; terminal shows placeholder until an action is run.
});
