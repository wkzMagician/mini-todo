import { contextBridge, ipcRenderer } from "electron";
import type { Granularity, Todo } from "../src/shared/todos.js";

const todoApi = {
  listTasks: (): Promise<Todo[]> => ipcRenderer.invoke("todos:list"),
  createTask: (title: string, granularity: Granularity): Promise<Todo[]> =>
    ipcRenderer.invoke("todos:create", { title, granularity }),
  completeTask: (id: string): Promise<Todo[]> =>
    ipcRenderer.invoke("todos:complete", id),
  updateTaskGranularity: (
    id: string,
    granularity: Granularity
  ): Promise<Todo[]> =>
    ipcRenderer.invoke("todos:update-granularity", { id, granularity }),
  renameTask: (id: string, title: string): Promise<Todo[]> =>
    ipcRenderer.invoke("todos:rename", { id, title }),
  reorderTasks: (
    granularity: Granularity,
    fromIndex: number,
    toIndex: number
  ): Promise<Todo[]> =>
    ipcRenderer.invoke("todos:reorder", { granularity, fromIndex, toIndex }),
  getOpenAtLogin: (): Promise<boolean> =>
    ipcRenderer.invoke("settings:get-open-at-login"),
  setOpenAtLogin: (enabled: boolean): Promise<boolean> =>
    ipcRenderer.invoke("settings:set-open-at-login", enabled),
  setCollapsed: (collapsed: boolean): Promise<void> =>
    ipcRenderer.invoke("window:set-collapsed", collapsed),
  closeWindow: (): void => {
    ipcRenderer.send("window:close");
  }
};

contextBridge.exposeInMainWorld("todoApi", todoApi);
