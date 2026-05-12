# Floating Todo Window Design

## Goal

Build a Windows desktop todo app that opens as a small always-on-top window, supports expanded and collapsed states, and lets the user switch between today, this week, this month, and this year task views.

## Product Behavior

- The app starts as a compact floating desktop window.
- The user can expand or collapse the content area.
- Expanded mode shows four granularity tabs: Today, This Week, This Month, This Year.
- The visible task list is filtered by the selected granularity.
- The user can create a task with a title and selected granularity.
- Completing a task deletes it immediately, so it is not shown again.

## Architecture

Use Electron for the Windows desktop shell and React for the renderer UI. Store tasks in Electron's user data directory as JSON. Keep task domain rules in a small shared TypeScript module so filtering, creation, and completion behavior can be tested without Electron.

## Components

- Electron main process creates a frameless, always-on-top window and exposes task persistence APIs through IPC.
- Preload script exposes a narrow `todoApi` bridge to the renderer.
- React renderer handles tab switching, expanded/collapsed state, task creation, and task completion.
- Shared todo logic owns task types, validation, creation, filtering, and deletion.

## Data Model

Each task has:

- `id`: stable string identifier.
- `title`: trimmed non-empty text.
- `granularity`: one of `day`, `week`, `month`, `year`.
- `createdAt`: ISO timestamp.

Completion removes the task from storage. No completed-task history is kept.

## Testing

Use Vitest for the shared todo logic. Cover task creation, blank-title rejection, granularity filtering, and completion deletion.
