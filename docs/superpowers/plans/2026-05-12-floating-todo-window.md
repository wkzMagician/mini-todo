# Floating Todo Window Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a lightweight Windows floating todo desktop app with expandable UI, time-granularity tabs, task creation, and delete-on-complete behavior.

**Architecture:** Electron owns the desktop window and JSON persistence. React owns the renderer UI. Shared TypeScript todo logic is tested independently with Vitest.

**Tech Stack:** Electron, Vite, React, TypeScript, Vitest.

---

### Task 1: Project Scaffold

**Files:**
- Create: `package.json`
- Create: `index.html`
- Create: `tsconfig.json`
- Create: `tsconfig.node.json`
- Create: `vite.config.ts`

- [ ] Add npm scripts for dev, build, preview, typecheck, and test.
- [ ] Configure Vite for React and Vitest jsdom tests.
- [ ] Configure TypeScript for renderer and Electron files.

### Task 2: Todo Domain Logic

**Files:**
- Create: `src/shared/todos.ts`
- Create: `src/shared/todos.test.ts`

- [ ] Write Vitest tests first for creation, filtering, completion deletion, and blank-title validation.
- [ ] Run the test and verify it fails because the module is missing.
- [ ] Implement the minimal todo logic.
- [ ] Run the test and verify it passes.

### Task 3: Electron Shell And Persistence

**Files:**
- Create: `electron/main.ts`
- Create: `electron/preload.ts`
- Create: `src/types/electron.d.ts`

- [ ] Create an always-on-top frameless Electron window.
- [ ] Store tasks in `app.getPath("userData")/todos.json`.
- [ ] Expose `listTasks`, `createTask`, and `completeTask` through IPC.
- [ ] Expose a typed renderer bridge as `window.todoApi`.

### Task 4: React Floating Todo UI

**Files:**
- Create: `src/main.tsx`
- Create: `src/App.tsx`
- Create: `src/styles.css`

- [ ] Build the expanded/collapsed shell.
- [ ] Add granularity tabs for today, week, month, and year.
- [ ] Add task list and complete buttons.
- [ ] Add task creation form with granularity selection.
- [ ] Style the app as a compact floating utility window.

### Task 5: Verification

**Files:**
- Modify: existing project files as needed.

- [ ] Run `npm test`.
- [ ] Run `npm run typecheck`.
- [ ] Run `npm run build`.
- [ ] Start the dev server and Electron app for manual verification.
