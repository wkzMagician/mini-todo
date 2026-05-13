export type Granularity = "day" | "week" | "month" | "year";

export interface Todo {
  id: string;
  title: string;
  granularity: Granularity;
  createdAt: string;
}

export interface CreateTodoInput {
  title: string;
  granularity: Granularity;
  now: Date;
  id: string;
}

export function createTodo(input: CreateTodoInput): Todo {
  const title = input.title.trim();

  assertTodoTitle(title);

  return {
    id: input.id,
    title,
    granularity: input.granularity,
    createdAt: input.now.toISOString()
  };
}

export function filterTodosByGranularity(
  todos: Todo[],
  granularity: Granularity
): Todo[] {
  return todos.filter((todo) => todo.granularity === granularity);
}

export function completeTodo(todos: Todo[], id: string): Todo[] {
  return todos.filter((todo) => todo.id !== id);
}

export function updateTodoGranularity(
  todos: Todo[],
  id: string,
  granularity: Granularity
): Todo[] {
  return todos.map((todo) =>
    todo.id === id
      ? {
          ...todo,
          granularity
        }
      : todo
  );
}

export function renameTodo(todos: Todo[], id: string, title: string): Todo[] {
  const nextTitle = title.trim();
  assertTodoTitle(nextTitle);

  return todos.map((todo) =>
    todo.id === id
      ? {
          ...todo,
          title: nextTitle
        }
      : todo
  );
}

export function reorderTodosWithinGranularity(
  todos: Todo[],
  granularity: Granularity,
  fromIndex: number,
  toIndex: number
): Todo[] {
  const granularityTodos = todos.filter((todo) => todo.granularity === granularity);
  const clampedFromIndex = clampIndex(fromIndex, granularityTodos.length - 1);
  const clampedToIndex = clampIndex(toIndex, granularityTodos.length - 1);
  const [movedTodo] = granularityTodos.splice(clampedFromIndex, 1);

  if (!movedTodo) {
    return todos;
  }

  granularityTodos.splice(clampedToIndex, 0, movedTodo);

  let nextGranularityIndex = 0;
  return todos.map((todo) =>
    todo.granularity === granularity
      ? granularityTodos[nextGranularityIndex++]
      : todo
  );
}

function assertTodoTitle(title: string): void {
  if (!title) {
    throw new Error("Task title is required");
  }
}

function clampIndex(index: number, maxIndex: number): number {
  if (maxIndex < 0) {
    return 0;
  }

  return Math.max(0, Math.min(index, maxIndex));
}
