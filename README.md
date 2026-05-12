# Todo Float

A compact always-on-top Windows desktop todo app built with Electron, React, Vite, and TypeScript.

## Development

```powershell
npm install
npm run dev
```

## Production Run

```powershell
npm run build
npm link
todo-float
```

## Windows Installer

```powershell
$env:ELECTRON_MIRROR='https://npmmirror.com/mirrors/electron/'
$env:electron_builder_binaries_mirror='https://npmmirror.com/mirrors/electron-builder-binaries/'
npm run dist:win
```

The installer is written to `release/`.

## Checks

```powershell
npm test
npm run typecheck
npm run build
```
