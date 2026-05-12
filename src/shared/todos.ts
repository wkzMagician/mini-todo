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

  if (!title) {
    throw new Error("Task title is required");
  }

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
