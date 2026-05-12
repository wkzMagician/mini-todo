import { describe, expect, it } from "vitest";
import {
  completeTodo,
  createTodo,
  filterTodosByGranularity,
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
});
