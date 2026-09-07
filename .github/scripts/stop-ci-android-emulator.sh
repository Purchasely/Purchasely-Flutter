#!/bin/bash
# Stop only the AVD owned by this workflow. `adb emu kill` has already been
# attempted by android-emulator-runner; this handles the observed case where
# QEMU remains alive after acknowledging that command.
set -uo pipefail

pattern='qemu-system-x86_64-headless.*-avd test'

if ! pgrep -f "$pattern" >/dev/null; then
  echo "[stop-ci-android-emulator] emulator process already stopped"
  exit 0
fi

echo "[stop-ci-android-emulator] terminating stuck test AVD process"
pkill -TERM -f "$pattern"

for _ in $(seq 1 10); do
  if ! pgrep -f "$pattern" >/dev/null; then
    echo "[stop-ci-android-emulator] emulator process stopped"
    exit 0
  fi
  sleep 1
done

echo "[stop-ci-android-emulator] forcing stuck test AVD process to stop"
pkill -KILL -f "$pattern" 2>/dev/null || true
sleep 1

if pgrep -f "$pattern" >/dev/null; then
  echo "[stop-ci-android-emulator] test AVD process survived SIGKILL"
  exit 1
fi

echo "[stop-ci-android-emulator] emulator process force-stopped"
