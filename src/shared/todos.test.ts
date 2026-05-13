import { describe, expect, it } from "vitest";
import {
  completeTodo,
  createTodo,
  filterTodosByGranularity,
  renameTodo,
  reorderTodosWithinGranularity,
  updateTodoGranularity,
  type Todo
} from "./todos";

describe("todo domain logic", () => {
  it("creates a todo with trimmed title and selected granularity", () => {
    const todo = createTodo({
      title: "  Read proposal  ",
      granularity: "week",
      now: new Date("2026-05-12T08:00:00.000Z"),
      id: "task-1"
    });

    expect(todo).toEqual({
      id: "task-1",
      title: "Read proposal",
      granularity: "week",
      createdAt: "2026-05-12T08:00:00.000Z"
    });
  });

  it("rejects blank titles", () => {
    expect(() =>
      createTodo({
        title: "   ",
        granularity: "day",
        now: new Date("2026-05-12T08:00:00.000Z"),
        id: "task-2"
      })
    ).toThrow("Task title is required");
  });

  it("filters todos by selected granularity", () => {
    const todos: Todo[] = [
      {
        id: "task-1",
        title: "Daily note",
        granularity: "day",
        createdAt: "2026-05-12T08:00:00.000Z"
      },
      {
        id: "task-2",
        title: "Monthly invoice",
        granularity: "month",
        createdAt: "2026-05-12T08:00:00.000Z"
      }
    ];

    expect(filterTodosByGranularity(todos, "month")).toEqual([todos[1]]);
  });

  it("removes completed todos", () => {
    const todos: Todo[] = [
      {
        id: "task-1",
        title: "Daily note",
        granularity: "day",
        createdAt: "2026-05-12T08:00:00.000Z"
      },
      {
        id: "task-2",
        title: "Yearly review",
        granularity: "year",
        createdAt: "2026-05-12T08:00:00.000Z"
      }
    ];

    expect(completeTodo(todos, "task-1")).toEqual([todos[1]]);
  });

  it("updates an existing todo granularity without changing other fields", () => {
    const todos: Todo[] = [
      {
        id: "task-1",
        title: "Weekly planning",
        granularity: "week",
        createdAt: "2026-05-12T08:00:00.000Z"
      },
      {
        id: "task-2",
        title: "Monthly invoice",
        granularity: "month",
        createdAt: "2026-05-12T08:00:00.000Z"
      }
    ];

    const updatedTodos = updateTodoGranularity(todos, "task-1", "day");

    expect(updatedTodos).toEqual([
      {
        id: "task-1",
        title: "Weekly planning",
        granularity: "day",
        createdAt: "2026-05-12T08:00:00.000Z"
      },
      todos[1]
    ]);
    expect(filterTodosByGranularity(updatedTodos, "day")).toEqual([
      updatedTodos[0]
    ]);
  });

  it("renames an existing todo with a trimmed title", () => {
    const todos: Todo[] = [
      {
        id: "task-1",
        title: "Old title",
        granularity: "day",
        createdAt: "2026-05-12T08:00:00.000Z"
      }
    ];

    expect(renameTodo(todos, "task-1", "  New title  ")).toEqual([
      {
        ...todos[0],
        title: "New title"
      }
    ]);
  });

  it("rejects blank titles when renaming a todo", () => {
    const todos: Todo[] = [
      {
        id: "task-1",
        title: "Old title",
        granularity: "day",
        createdAt: "2026-05-12T08:00:00.000Z"
      }
    ];

    expect(() => renameTodo(todos, "task-1", "   ")).toThrow(
      "Task title is required"
    );
  });

  it("reorders todos within one granularity and preserves other granularities", () => {
    const todos: Todo[] = [
      {
        id: "task-1",
        title: "First daily task",
        granularity: "day",
        createdAt: "2026-05-12T08:00:00.000Z"
      },
      {
        id: "task-2",
        title: "Weekly task",
        granularity: "week",
        createdAt: "2026-05-12T08:01:00.000Z"
      },
      {
        id: "task-3",
        title: "Second daily task",
        granularity: "day",
        createdAt: "2026-05-12T08:02:00.000Z"
      }
    ];

    expect(reorderTodosWithinGranularity(todos, "day", 0, 1)).toEqual([
      todos[2],
      todos[1],
      todos[0]
    ]);
  });
});
