import type { Granularity, Todo } from "../shared/todos";

export interface TodoApi {
  listTasks: () => Promise<Todo[]>;
  createTask: (title: string, granularity: Granularity) => Promise<Todo[]>;
  completeTask: (id: string) => Promise<Todo[]>;
  updateTaskGranularity: (
    id: string,
    granularity: Granularity
  ) => Promise<Todo[]>;
  renameTask: (id: string, title: string) => Promise<Todo[]>;
  reorderTasks: (
    granularity: Granularity,
    fromIndex: number,
    toIndex: number
  ) => Promise<Todo[]>;
  getOpenAtLogin: () => Promise<boolean>;
  setOpenAtLogin: (enabled: boolean) => Promise<boolean>;
  setCollapsed: (collapsed: boolean) => Promise<void>;
  closeWindow: () => void;
}

declare global {
  interface Window {
    todoApi: TodoApi;
  }
}
