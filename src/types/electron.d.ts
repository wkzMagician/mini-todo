import type { Granularity, Todo } from "../shared/todos";

export interface TodoApi {
  listTasks: () => Promise<Todo[]>;
  createTask: (title: string, granularity: Granularity) => Promise<Todo[]>;
  completeTask: (id: string) => Promise<Todo[]>;
  updateTaskGranularity: (
    id: string,
    granularity: Granularity
  ) => Promise<Todo[]>;
  setCollapsed: (collapsed: boolean) => Promise<void>;
  closeWindow: () => void;
}

declare global {
  interface Window {
    todoApi: TodoApi;
  }
}
