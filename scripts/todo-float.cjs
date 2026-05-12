#!/usr/bin/env node

const { spawn } = require("node:child_process");
const path = require("node:path");
const electron = require("electron");

const appRoot = path.resolve(__dirname, "..");
const child = spawn(electron, [appRoot], {
  cwd: appRoot,
  env: process.env,
  stdio: "inherit",
  windowsHide: false
});

child.on("exit", (code) => {
  process.exit(code ?? 0);
});
