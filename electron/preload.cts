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
  setCollapsed: (collapsed: boolean): Promise<void> =>
    ipcRenderer.invoke("window:set-collapsed", collapsed),
  closeWindow: (): void => {
    ipcRenderer.send("window:close");
  }
};

contextBridge.exposeInMainWorld("todoApi", todoApi);
