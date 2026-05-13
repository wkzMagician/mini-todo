import { Check, ChevronDown, ChevronUp, GripVertical, Plus, Settings, X } from "lucide-react";
import { FormEvent, useEffect, useMemo, useState } from "react";
import {
  createTodo,
  completeTodo,
  filterTodosByGranularity,
  renameTodo,
  reorderTodosWithinGranularity,
  updateTodoGranularity,
  type Granularity,
  type Todo
} from "./shared/todos";
import type { TodoApi } from "./types/electron";

const granularityOptions: Array<{ value: Granularity; label: string }> = [
  { value: "day", label: "今天" },
  { value: "week", label: "本周" },
  { value: "month", label: "本月" },
  { value: "year", label: "今年" }
];

const previewStorageKey = "todo-float.tasks";

function loadPreviewTodos(): Todo[] {
  try {
    const rawTodos = localStorage.getItem(previewStorageKey);
    const parsedTodos = rawTodos ? (JSON.parse(rawTodos) as Todo[]) : [];
    return Array.isArray(parsedTodos) ? parsedTodos : [];
  } catch {
    return [];
  }
}

function savePreviewTodos(todos: Todo[]): void {
  localStorage.setItem(previewStorageKey, JSON.stringify(todos));
}

const browserPreviewApi: TodoApi = (() => {
  let previewTodos: Todo[] = loadPreviewTodos();

  return {
    listTasks: async () => previewTodos,
    createTask: async (title, granularity) => {
      previewTodos = [
        ...previewTodos,
        createTodo({
          title,
          granularity,
          now: new Date(),
          id: crypto.randomUUID()
        })
      ];
      savePreviewTodos(previewTodos);
      return previewTodos;
    },
    completeTask: async (id) => {
      previewTodos = completeTodo(previewTodos, id);
      savePreviewTodos(previewTodos);
      return previewTodos;
    },
    updateTaskGranularity: async (id, granularity) => {
      previewTodos = updateTodoGranularity(previewTodos, id, granularity);
      savePreviewTodos(previewTodos);
      return previewTodos;
    },
    renameTask: async (id, title) => {
      previewTodos = renameTodo(previewTodos, id, title);
      savePreviewTodos(previewTodos);
      return previewTodos;
    },
    reorderTasks: async (granularity, fromIndex, toIndex) => {
      previewTodos = reorderTodosWithinGranularity(
        previewTodos,
        granularity,
        fromIndex,
        toIndex
      );
      savePreviewTodos(previewTodos);
      return previewTodos;
    },
    getOpenAtLogin: async () => false,
    setOpenAtLogin: async () => false,
    setCollapsed: async () => undefined,
    closeWindow: () => {
      window.close();
    }
  };
})();

export function App() {
  const todoApi = window.todoApi ?? browserPreviewApi;
  const [todos, setTodos] = useState<Todo[]>([]);
  const [selectedGranularity, setSelectedGranularity] =
    useState<Granularity>("day");
  const [newTitle, setNewTitle] = useState("");
  const [newGranularity, setNewGranularity] = useState<Granularity>("day");
  const [collapsed, setCollapsedState] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [editingTodoId, setEditingTodoId] = useState<string | null>(null);
  const [editingTitle, setEditingTitle] = useState("");
  const [draggedTodoId, setDraggedTodoId] = useState<string | null>(null);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [openAtLogin, setOpenAtLogin] = useState(false);

  useEffect(() => {
    todoApi
      .listTasks()
      .then(setTodos)
      .catch(() => setError("读取任务失败"));
  }, [todoApi]);

  useEffect(() => {
    todoApi
      .getOpenAtLogin()
      .then(setOpenAtLogin)
      .catch(() => setOpenAtLogin(false));
  }, [todoApi]);

  const visibleTodos = useMemo(
    () => filterTodosByGranularity(todos, selectedGranularity),
    [selectedGranularity, todos]
  );

  const selectedLabel =
    granularityOptions.find((option) => option.value === selectedGranularity)
      ?.label ?? "今天";

  async function toggleCollapsed() {
    const nextCollapsed = !collapsed;
    setCollapsedState(nextCollapsed);
    await todoApi.setCollapsed(nextCollapsed);
  }

  async function createTask(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);

    try {
      const nextTodos = await todoApi.createTask(
        newTitle,
        newGranularity
      );
      setTodos(nextTodos);
      setNewTitle("");
      setSelectedGranularity(newGranularity);
    } catch {
      setError("请输入任务内容");
    }
  }

  async function completeTask(id: string) {
    setError(null);

    try {
      setTodos(await todoApi.completeTask(id));
    } catch {
      setError("完成任务失败");
    }
  }

  async function updateTaskGranularity(id: string, granularity: Granularity) {
    setError(null);

    try {
      const nextTodos = await todoApi.updateTaskGranularity(id, granularity);
      setTodos(nextTodos);
      setSelectedGranularity(granularity);
    } catch {
      setError("更新任务粒度失败");
    }
  }

  function startEditingTask(todo: Todo) {
    setEditingTodoId(todo.id);
    setEditingTitle(todo.title);
  }

  async function saveEditingTask() {
    if (!editingTodoId) {
      return;
    }

    setError(null);

    try {
      setTodos(await todoApi.renameTask(editingTodoId, editingTitle));
      setEditingTodoId(null);
      setEditingTitle("");
    } catch {
      setError("请输入任务内容");
    }
  }

  function cancelEditingTask() {
    setEditingTodoId(null);
    setEditingTitle("");
  }

  async function reorderTask(targetTodoId: string) {
    if (!draggedTodoId || draggedTodoId === targetTodoId) {
      return;
    }

    const fromIndex = visibleTodos.findIndex((todo) => todo.id === draggedTodoId);
    const toIndex = visibleTodos.findIndex((todo) => todo.id === targetTodoId);

    if (fromIndex < 0 || toIndex < 0) {
      return;
    }

    setError(null);

    try {
      setTodos(await todoApi.reorderTasks(selectedGranularity, fromIndex, toIndex));
    } catch {
      setError("更新任务顺序失败");
    } finally {
      setDraggedTodoId(null);
    }
  }

  async function toggleOpenAtLogin(enabled: boolean) {
    setError(null);

    try {
      setOpenAtLogin(await todoApi.setOpenAtLogin(enabled));
    } catch {
      setError("更新开机自启动失败");
    }
  }

  return (
    <main className={collapsed ? "app app--collapsed" : "app"}>
      <header className="titlebar">
        <button
          className="icon-button"
          type="button"
          onClick={toggleCollapsed}
          title={collapsed ? "展开" : "折叠"}
          aria-label={collapsed ? "展开" : "折叠"}
        >
          {collapsed ? <ChevronDown size={18} /> : <ChevronUp size={18} />}
        </button>

        <div className="titlebar__summary">
          <span className="titlebar__title">Mini Todo</span>
          <span className="titlebar__meta">
            {selectedLabel} · {visibleTodos.length}
          </span>
        </div>

        <button
          className="icon-button"
          type="button"
          onClick={() => setSettingsOpen((value) => !value)}
          title="设置"
          aria-label="设置"
        >
          <Settings size={17} />
        </button>

        <button
          className="icon-button icon-button--danger"
          type="button"
          onClick={() => void todoApi.closeWindow()}
          title="关闭"
          aria-label="关闭"
        >
          <X size={17} />
        </button>
      </header>

      {!collapsed && (
        <section className="panel">
          {settingsOpen && (
            <section className="settings-panel" aria-label="设置">
              <label className="setting-row">
                <span>开机自启动</span>
                <input
                  type="checkbox"
                  checked={openAtLogin}
                  onChange={(event) => void toggleOpenAtLogin(event.target.checked)}
                />
              </label>
            </section>
          )}

          <nav className="tabs" aria-label="任务粒度">
            {granularityOptions.map((option) => (
              <button
                className={
                  option.value === selectedGranularity
                    ? "tab tab--active"
                    : "tab"
                }
                key={option.value}
                type="button"
                onClick={() => setSelectedGranularity(option.value)}
              >
                {option.label}
              </button>
            ))}
          </nav>

          <section className="task-list" aria-label={`${selectedLabel}任务`}>
            {visibleTodos.length === 0 ? (
              <div className="empty">暂无任务</div>
            ) : (
              visibleTodos.map((todo) => (
                <article
                  className={
                    draggedTodoId === todo.id ? "task task--dragging" : "task"
                  }
                  draggable={editingTodoId !== todo.id}
                  key={todo.id}
                  onDragStart={(event) => {
                    event.dataTransfer.effectAllowed = "move";
                    setDraggedTodoId(todo.id);
                  }}
                  onDragOver={(event) => {
                    event.preventDefault();
                    event.dataTransfer.dropEffect = "move";
                  }}
                  onDrop={(event) => {
                    event.preventDefault();
                    void reorderTask(todo.id);
                  }}
                  onDragEnd={() => setDraggedTodoId(null)}
                >
                  <GripVertical className="drag-handle" size={17} aria-hidden />
                  {editingTodoId === todo.id ? (
                    <input
                      className="task__edit-input"
                      value={editingTitle}
                      autoFocus
                      onChange={(event) => setEditingTitle(event.target.value)}
                      onBlur={() => void saveEditingTask()}
                      onKeyDown={(event) => {
                        if (event.key === "Enter") {
                          void saveEditingTask();
                        }

                        if (event.key === "Escape") {
                          cancelEditingTask();
                        }
                      }}
                      aria-label={`编辑 ${todo.title}`}
                    />
                  ) : (
                    <button
                      className="task__title"
                      type="button"
                      onDoubleClick={() => startEditingTask(todo)}
                      title="双击修改任务标题"
                    >
                      {todo.title}
                    </button>
                  )}
                  <select
                    className="task__granularity"
                    value={todo.granularity}
                    onChange={(event) =>
                      void updateTaskGranularity(
                        todo.id,
                        event.target.value as Granularity
                      )
                    }
                    aria-label={`修改 ${todo.title} 的任务粒度`}
                  >
                    {granularityOptions.map((option) => (
                      <option key={option.value} value={option.value}>
                        {option.label}
                      </option>
                    ))}
                  </select>
                  <button
                    className="complete-button"
                    type="button"
                    onClick={() => void completeTask(todo.id)}
                    title="完成"
                    aria-label={`完成 ${todo.title}`}
                  >
                    <Check size={17} />
                  </button>
                </article>
              ))
            )}
          </section>

          <form className="new-task" onSubmit={(event) => void createTask(event)}>
            <input
              value={newTitle}
              onChange={(event) => setNewTitle(event.target.value)}
              placeholder="新任务"
              aria-label="新任务"
            />
            <select
              value={newGranularity}
              onChange={(event) =>
                setNewGranularity(event.target.value as Granularity)
              }
              aria-label="任务粒度"
            >
              {granularityOptions.map((option) => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
            <button className="add-button" type="submit" title="添加" aria-label="添加">
              <Plus size={18} />
            </button>
          </form>

          {error && <div className="error">{error}</div>}
        </section>
      )}
    </main>
  );
}
