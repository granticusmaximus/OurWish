import { app, BrowserWindow } from 'electron';
import fs from 'node:fs';
import net from 'node:net';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const isDev = !app.isPackaged;
const defaultPort = Number(process.env.PORT || 5001);
let activePort = defaultPort;
const devServerUrl = 'http://127.0.0.1:5175';
const productionWebUrl = 'http://localhost:5175';
const useEmbeddedServer = isDev || process.env.ELECTRON_USE_EMBEDDED_SERVER === 'true';

function resolveDatabasePath() {
  if (process.env.OURWISH_DB_PATH) {
    return process.env.OURWISH_DB_PATH;
  }

  if (!app.isPackaged) {
    return path.resolve(__dirname, '..', 'ourwish.db');
  }

  return path.join(app.getPath('userData'), 'ourwish.db');
}

function resolveStartUrl() {
  if (process.env.ELECTRON_START_URL) {
    return process.env.ELECTRON_START_URL;
  }

  return isDev ? devServerUrl : productionWebUrl;
}

function resolveServerEntry() {
  if (!app.isPackaged) {
    return path.resolve(__dirname, '..', 'build', 'server', 'index.js');
  }

  const asarPath = path.join(process.resourcesPath, 'app.asar', 'build', 'server', 'index.js');
  const unpackedPath = path.join(process.resourcesPath, 'app.asar.unpacked', 'build', 'server', 'index.js');
  return fs.existsSync(asarPath) ? asarPath : unpackedPath;
}

async function waitForServer(url, timeoutMs = 20000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    try {
      const response = await fetch(url);
      if (response.ok) {
        return;
      }
    } catch {
      // Keep polling until timeout.
    }
    await new Promise((resolve) => setTimeout(resolve, 350));
  }
  throw new Error(`Timed out waiting for server: ${url}`);
}

async function isPortFree(port) {
  return new Promise((resolve) => {
    const tester = net
      .createServer()
      .once('error', () => resolve(false))
      .once('listening', () => {
        tester.close(() => resolve(true));
      });

    tester.listen({ port, host: '::' });
  });
}

async function findAvailablePort(startPort, maxAttempts = 100) {
  for (let offset = 0; offset < maxAttempts; offset += 1) {
    const candidate = startPort + offset;
    // eslint-disable-next-line no-await-in-loop
    if (await isPortFree(candidate)) {
      return candidate;
    }
  }

  throw new Error(`No free local port found starting from ${startPort}`);
}

async function startEmbeddedServerIfNeeded() {
  if (!useEmbeddedServer) {
    return;
  }

  activePort = await findAvailablePort(defaultPort);
  process.env.NODE_ENV = 'production';
  process.env.PORT = String(activePort);
  process.env.OURWISH_DB_PATH = resolveDatabasePath();
  process.env.SESSION_COOKIE_SECURE = process.env.SESSION_COOKIE_SECURE || 'false';

  const serverEntry = resolveServerEntry();
  if (!fs.existsSync(serverEntry)) {
    throw new Error(`Server build not found at ${serverEntry}. Run npm run build:server first.`);
  }

  await import(pathToFileURL(serverEntry).href);
  await waitForServer(`http://127.0.0.1:${activePort}/api/health`);
}

function createMainWindow() {
  const preloadPath = path.join(__dirname, 'preload.cjs');
  const window = new BrowserWindow({
    width: 1280,
    height: 840,
    minWidth: 1100,
    minHeight: 720,
    autoHideMenuBar: true,
    webPreferences: {
      preload: preloadPath,
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  window.loadURL(resolveStartUrl());
}

app.whenReady()
  .then(startEmbeddedServerIfNeeded)
  .then(createMainWindow)
  .catch((error) => {
    console.error('Failed to start desktop app:', error);
    app.quit();
  });

app.on('window-all-closed', () => {
  app.quit();
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    createMainWindow();
  }
});
