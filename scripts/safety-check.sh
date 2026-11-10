#!/bin/sh
# Checks, on a running emulator with the app installed, what protects an
# answer given from a notification and a terminal from a stray tap. Uses the
# built-in demo: Codex asks to run a migration 15 s in. Fails on the first
# thing that isn't as it should be, leaving failed.png and ui.xml in OUT.
set -eu
OUT=${1:-screenshots}/checks
HERE=$(dirname "$0")
PKG=io.github.javamomma.herdr
ACT=$PKG/herdr.app.MainActivity
PIN=1234
mkdir -p "$OUT"

shot() { adb exec-out screencap -p > "$OUT/$1.png"; }
dump() { adb shell uiautomator dump /sdcard/ui.xml > /dev/null 2>&1 || true; adb exec-out cat /sdcard/ui.xml > "$OUT/ui.xml"; }
fail() { shot failed; echo "FAILED: $1"; adb shell locksettings clear --old $PIN > /dev/null 2>&1 || true; exit 1; }
sees() { dump; python3 "$HERE/ui.py" --has "$OUT/ui.xml" "$1" > /dev/null; }
must() { sees "$1" || fail "expected to see: $1"; echo "ok: shows \"$1\""; }
mustnot() { if sees "$1"; then fail "should not see: $1"; fi; echo "ok: no \"$1\""; }
tap() { dump; xy=$(python3 "$HERE/ui.py" "$OUT/ui.xml" "$1") || fail "nothing to tap: $1"; adb shell input tap $xy; sleep 2; }

adb shell wm size 1968x2184
adb shell wm density 420
adb shell am start -W -S -n $ACT --ez demo true > /dev/null
sleep 22

echo "1. A blocked agent's notification shows its question and answers with its own option"
adb shell cmd statusbar expand-notifications
sleep 2
must "needs you"
must "npx prisma migrate deploy"
must "Yes, run it"
must "Deny"
shot 1-question
adb shell cmd statusbar collapse
sleep 1

echo "2. Closing a pane with an agent in it asks first"
tap "More"
tap "Close pane"
must "Close this pane?"
must "This ends"
shot 2-close-asks
tap "Cancel"
mustnot "Close this pane?"

echo "3. A locked phone set to hide sensitive notifications shows no question"
adb shell settings put secure lock_screen_allow_private_notifications 0
adb shell locksettings set-pin $PIN
adb shell input keyevent KEYCODE_SLEEP
sleep 2
adb shell input keyevent KEYCODE_WAKEUP
sleep 3
shot 3-locked
mustnot "prisma"
mustnot "Yes, run it"
adb shell input keyevent KEYCODE_MENU
sleep 2
adb shell input text $PIN
adb shell input keyevent KEYCODE_ENTER
sleep 3
adb shell locksettings clear --old $PIN
adb shell settings put secure lock_screen_allow_private_notifications 1

echo "4. Allow, tapped while the agent still shows that question, is sent and the notification goes"
adb shell cmd statusbar expand-notifications
sleep 2
tap "Yes, run it"
sleep 3
mustnot "Yes, run it"
mustnot "Not sent"
shot 4-answered
adb shell cmd statusbar collapse

adb shell wm size reset
adb shell wm density reset
echo "All checks passed."
