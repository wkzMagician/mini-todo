import { app, BrowserWindow, ipcMain } from "electron";
import {
  closeSync,
  existsSync,
  fsyncSync,
  mkdirSync,
  openSync,
  readFileSync,
  writeFileSync
} from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { randomUUID } from "node:crypto";
import {
  completeTodo,
  createTodo,
  renameTodo,
  reorderTodosWithinGranularity,
  updateTodoGranularity,
  type Granularity,
  type Todo
} from "../src/shared/todos.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
const expandedWindowHeight = 520;
const collapsedWindowHeight = 56;
const appRoot = join(__dirname, "../..");

app.commandLine.appendSwitch("disable-http-cache");
app.commandLine.appendSwitch("disable-gpu-shader-disk-cache");

const validGranularities = new Set<Granularity>([
  "day",
  "week",
  "month",
  "year"
]);

function quitApplication(): void {
  for (const window of BrowserWindow.getAllWindows()) {
    window.destroy();
  }

  app.exit(0);
}

function getTodosPath(): string {
  return join(app.getPath("userData"), "todos.json");
}

function getWindowIconPath(): string | undefined {
  const iconPaths = [
    join(appRoot, "public", "icon.png"),
    join(appRoot, "dist", "icon.png")
  ];

  return iconPaths.find((iconPath) => existsSync(iconPath));
}

function readTodos(): Todo[] {
  const filePath = getTodosPath();

  if (!existsSync(filePath)) {
    return [];
  }

  const raw = readFileSync(filePath, "utf8");
  if (!raw.trim()) {
    return [];
  }

  const parsed = JSON.parse(raw) as Todo[];
  return Array.isArray(parsed) ? parsed : [];
}

function writeTodos(todos: Todo[]): void {
  const filePath = getTodosPath();
  mkdirSync(dirname(filePath), { recursive: true });

  const file = openSync(filePath, "w");
  try {
    writeFileSync(file, `${JSON.stringify(todos, null, 2)}\n`, "utf8");
    fsyncSync(file);
  } finally {
    closeSync(file);
  }
}

function assertGranularity(value: string): asserts value is Granularity {
  if (!validGranularities.has(value as Granularity)) {
    throw new Error("Invalid granularity");
  }
}

function createWindow(): void {
  const window = new BrowserWindow({
    width: 340,
    height: expandedWindowHeight,
    minWidth: 280,
    minHeight: collapsedWindowHeight,
    alwaysOnTop: true,
    frame: false,
    transparent: false,
    resizable: true,
    skipTaskbar: false,
    backgroundColor: "#f8fafc",
    icon: getWindowIconPath(),
    webPreferences: {
      preload: join(__dirname, "preload.cjs"),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  window.setAlwaysOnTop(true, "floating");

  const devServerUrl = process.env.VITE_DEV_SERVER_URL;
  if (devServerUrl) {
    void window.loadURL(devServerUrl);
    return;
  }

  void window.loadFile(join(__dirname, "../../dist/index.html"));
}

const hasSingleInstanceLock = app.requestSingleInstanceLock();

if (!hasSingleInstanceLock) {
  app.exit(0);
}

app.on("second-instance", () => {
  const existingWindow = BrowserWindow.getAllWindows()[0];
  if (!existingWindow) {
    return;
  }

  if (existingWindow.isMinimized()) {
    existingWindow.restore();
  }

  existingWindow.show();
  existingWindow.focus();
});

if (hasSingleInstanceLock) {
  app.whenReady().then(() => {
  ipcMain.handle("todos:list", () => readTodos());

  ipcMain.handle(
    "todos:create",
    (_event, input: { title: string; granularity: string }) => {
      assertGranularity(input.granularity);
      const todos = readTodos();
      const todo = createTodo({
        title: input.title,
        granularity: input.granularity,
        now: new Date(),
        id: randomUUID()
      });
      const nextTodos = [...todos, todo];
      writeTodos(nextTodos);
      return readTodos();
    }
  );

  ipcMain.handle("todos:complete", (_event, id: string) => {
    const nextTodos = completeTodo(readTodos(), id);
    writeTodos(nextTodos);
    return readTodos();
  });

  ipcMain.handle(
    "todos:update-granularity",
    (_event, input: { id: string; granularity: string }) => {
      assertGranularity(input.granularity);
      const nextTodos = updateTodoGranularity(
        readTodos(),
        input.id,
        input.granularity
      );
      writeTodos(nextTodos);
      return readTodos();
    }
  );

  ipcMain.handle(
    "todos:rename",
    (_event, input: { id: string; title: string }) => {
      const nextTodos = renameTodo(readTodos(), input.id, input.title);
      writeTodos(nextTodos);
      return readTodos();
    }
  );

  ipcMain.handle(
    "todos:reorder",
    (
      _event,
      input: { granularity: string; fromIndex: number; toIndex: number }
    ) => {
      assertGranularity(input.granularity);
      const nextTodos = reorderTodosWithinGranularity(
        readTodos(),
        input.granularity,
        input.fromIndex,
        input.toIndex
      );
      writeTodos(nextTodos);
      return readTodos();
    }
  );

  ipcMain.handle("settings:get-open-at-login", () => {
    return app.getLoginItemSettings().openAtLogin;
  });

  ipcMain.handle("settings:set-open-at-login", (_event, enabled: boolean) => {
    app.setLoginItemSettings({
      openAtLogin: enabled,
      path: process.execPath
    });

    return app.getLoginItemSettings().openAtLogin;
  });

  ipcMain.handle("window:set-collapsed", (event, collapsed: boolean) => {
    const window = BrowserWindow.fromWebContents(event.sender);
    if (!window) {
      return;
    }

    const [contentWidth] = window.getContentSize();
    window.setMinimumSize(280, collapsedWindowHeight);
    window.setContentSize(
      contentWidth,
      collapsed ? collapsedWindowHeight : expandedWindowHeight,
      true
    );
  });

  ipcMain.on("window:close", () => {
    quitApplication();
  });

  createWindow();

  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
  });
}

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") {
    app.quit();
  }
});
