'use strict';

const { app, BrowserWindow, ipcMain, dialog } = require('electron');
const path = require('path');
const spawn = require('cross-spawn');
const fs = require('fs');

// Keep a global reference of the window to prevent garbage collection
let mainWindow = null;

// ---------------------------------------------------------------------------
// Window creation
// ---------------------------------------------------------------------------
function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1000,
    height: 750,
    minWidth: 800,
    minHeight: 600,
    title: 'Awesome Android Root Helper',
    backgroundColor: '#0d1117',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,   // Isolate renderer context from Node
      nodeIntegration: false,   // Renderer cannot access Node directly
      sandbox: false,           // Preload needs access to Node for IPC
      webSecurity: true,
    },
    icon: undefined, // Add icon path here if you have one
  });

  mainWindow.loadFile('index.html');

  // Uncomment to open DevTools during development:
  // mainWindow.webContents.openDevTools();

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

app.whenReady().then(() => {
  createWindow();

  app.on('activate', () => {
    // macOS: re-create window when dock icon clicked and no windows open
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Resolve the absolute path to a bundled shell script.
 */
function scriptPath(name) {
  return path.join(__dirname, 'scripts', name);
}

/**
 * Send a log line to the renderer's terminal view.
 */
function sendLog(event, level, text) {
  // 'level' is one of: 'info' | 'success' | 'error' | 'warn'
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send('terminal:line', { level, text });
  }
}

/**
 * Spawn a bash script and stream its stdout/stderr back to the renderer.
 * Returns a Promise that resolves with the exit code.
 */
function runScript(event, scriptFile, args = []) {
  return new Promise((resolve) => {
    const filePath = scriptPath(scriptFile);

    // Verify the script exists before attempting to run it
    if (!fs.existsSync(filePath)) {
      sendLog(event, 'error', `[ERROR] Script not found: ${filePath}`);
      resolve(1);
      return;
    }

    // Ensure the script is executable (important after npm install on some systems)
    try {
      fs.chmodSync(filePath, '755');
    } catch (chmodErr) {
      sendLog(event, 'warn', `[WARN] Could not chmod script: ${chmodErr.message}`);
    }

    sendLog(event, 'info', `[RUN] bash ${scriptFile} ${args.join(' ')}`);

    const child = spawn('bash', [filePath, ...args], {
      env: {
        ...process.env,
        // Make sure common tool paths are available on macOS / Linux
        PATH: `/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${process.env.PATH || ''}`,
      },
      shell: false, // We are already invoking bash explicitly
    });

    child.stdout.on('data', (data) => {
      const lines = data.toString().split('\n');
      lines.forEach((line) => {
        if (line.trim() !== '') sendLog(event, 'info', line);
      });
    });

    child.stderr.on('data', (data) => {
      const lines = data.toString().split('\n');
      lines.forEach((line) => {
        if (line.trim() !== '') sendLog(event, 'error', line);
      });
    });

    child.on('error', (err) => {
      sendLog(event, 'error', `[ERROR] Failed to start process: ${err.message}`);
      resolve(1);
    });

    child.on('close', (code) => {
      const level = code === 0 ? 'success' : 'error';
      sendLog(event, level, `[EXIT] Process exited with code ${code}`);
      resolve(code);
    });
  });
}

// ---------------------------------------------------------------------------
// IPC Handlers
// ---------------------------------------------------------------------------

/**
 * Handler: check-device
 * Runs device_check.sh and streams output to the renderer.
 */
ipcMain.on('device:check', async (event) => {
  sendLog(event, 'info', '══════════════════════════════════════');
  sendLog(event, 'info', '  Checking device status...');
  sendLog(event, 'info', '══════════════════════════════════════');

  const code = await runScript(event, 'device_check.sh');

  if (code === 0) {
    sendLog(event, 'success', '✔  Device check complete.');
  } else {
    sendLog(event, 'error', '✘  Device check failed. See output above.');
  }

  // Notify renderer that the operation finished
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send('device:check:done', { code });
  }
});

/**
 * Handler: flash-root
 * Opens a file picker then runs flash_root.sh with the selected file path.
 */
ipcMain.on('device:flash', async (event) => {
  // Open a native file dialog to select the patched boot image
  const result = await dialog.showOpenDialog(mainWindow, {
    title: 'Select Patched Boot Image',
    filters: [
      { name: 'Boot Images', extensions: ['img'] },
      { name: 'All Files', extensions: ['*'] },
    ],
    properties: ['openFile'],
  });

  if (result.canceled || result.filePaths.length === 0) {
    sendLog(event, 'warn', '[CANCELLED] File selection was cancelled.');
    if (mainWindow && !mainWindow.isDestroyed()) {
      mainWindow.webContents.send('device:flash:done', { code: -1 });
    }
    return;
  }

  const selectedFile = result.filePaths[0];

  sendLog(event, 'info', '══════════════════════════════════════');
  sendLog(event, 'info', '  Starting boot flash operation...');
  sendLog(event, 'info', `  File: ${selectedFile}`);
  sendLog(event, 'info', '══════════════════════════════════════');

  const code = await runScript(event, 'flash_root.sh', [selectedFile]);

  if (code === 0) {
    sendLog(event, 'success', '✔  Flash complete. Device is rebooting.');
  } else {
    sendLog(event, 'error', '✘  Flash failed. Check the output above for details.');
  }

  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send('device:flash:done', { code });
  }
});

/**
 * Handler: clear-terminal
 * Lets the renderer ask the main process to broadcast a clear event back.
 */
ipcMain.on('terminal:clear', () => {
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send('terminal:clear');
  }
});
