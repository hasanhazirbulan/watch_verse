#!/usr/bin/env bash
# Captures the App Store screenshot set on one simulator by running
# integration_test/app_store_screenshots_test.dart through `flutter drive`.
#
#   tool/app_store_screenshots.sh <simulator-udid> [out-dir] [simctl-display]
#
# out-dir defaults to build/screenshots/<simulator name>. simctl-display is
# passed to `xcrun simctl io screenshot --display=…` (only needed for a
# device with several displays, e.g. the iPhone Duo — boot it folded or
# unfolded first, then pass the display that is showing the app).
#
# What it does: boots the simulator if needed, sets the 9:41 / full-battery
# status bar, runs the test in SCREENSHOT_CAPTURE=simctl mode and grabs a
# full-resolution `simctl io screenshot` every time the test prints
# `WVSHOT <name>`, then strips any alpha channel (App Store Connect rejects
# it) and prints each PNG's pixel size. Needs secrets.json (TMDB key) in the
# repo root. Demo accounts are deleted by the test itself; if a run is
# killed, look for the `SHOTS account …` lines in the log and delete those
# accounts by hand.
set -euo pipefail

udid="${1:?usage: $0 <simulator-udid> [out-dir] [simctl-display]}"
cd "$(dirname "$0")/.."
name="$(xcrun simctl list devices | grep "$udid" | sed -E 's/^ *(.*) \([0-9A-F-]{36}\).*/\1/' | tr ' ' '_' )"
out="${2:-build/screenshots/${name:-device}}"
display="${3:-}"
mkdir -p "$out"

booted_here=0
if ! xcrun simctl list devices booted | grep -q "$udid"; then
  xcrun simctl boot "$udid"
  booted_here=1
fi
xcrun simctl bootstatus "$udid" -b >/dev/null
# A new simulator inherits the Mac's region; en_US gives the 12-hour "9:41"
# status-bar clock (other regions render it "09:41"). Takes a reboot.
if [[ "$(xcrun simctl spawn "$udid" defaults read -g AppleLocale 2>/dev/null)" != "en_US" ]]; then
  xcrun simctl spawn "$udid" defaults write -g AppleLocale -string en_US
  xcrun simctl spawn "$udid" defaults write -g AppleLanguages -array en
  xcrun simctl shutdown "$udid"
  xcrun simctl boot "$udid"
  xcrun simctl bootstatus "$udid" -b >/dev/null
fi
xcrun simctl status_bar "$udid" override --time 9:41 --dataNetwork wifi \
  --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 \
  --batteryState charged --batteryLevel 100

log="$out/run.log"
echo "Running the screenshot test on $udid → $out (log: $log)"
set +e
SCREENSHOT_DIR="$out" flutter drive \
  --driver=test_driver/screenshot_driver.dart \
  --target=integration_test/app_store_screenshots_test.dart \
  -d "$udid" --dart-define-from-file=secrets.json \
  --dart-define=SCREENSHOT_CAPTURE=simctl 2>&1 | tee "$log" |
while IFS= read -r line; do
  if [[ "$line" =~ WVSHOT\ ([A-Za-z0-9_]+) ]]; then
    shot="${BASH_REMATCH[1]}"
    sleep 1
    xcrun simctl io "$udid" screenshot ${display:+--display="$display"} \
      "$out/$shot.png" >/dev/null 2>&1 && echo "captured $shot"
  elif [[ "$line" =~ (SHOTS|All\ tests|Some\ tests|FAILED|Exception) ]]; then
    echo "$line"
  fi
done
status=${PIPESTATUS[0]}
set -e

xcrun simctl status_bar "$udid" clear || true
if [[ $booted_here == 1 ]]; then xcrun simctl shutdown "$udid" || true; fi

for f in "$out"/*.png; do
  [[ -e "$f" ]] || continue
  if [[ "$(sips -g hasAlpha "$f" | awk '/hasAlpha/ {print $2}')" == "yes" ]]; then
    # PNG → JPEG (max quality) → PNG drops the alpha channel.
    sips -s format jpeg -s formatOptions 100 "$f" --out "$f.jpg" >/dev/null
    sips -s format png "$f.jpg" --out "$f" >/dev/null
    rm "$f.jpg"
  fi
  echo "$(basename "$f"): $(sips -g pixelWidth -g pixelHeight -g hasAlpha "$f" |
    awk '/pixelWidth/ {w=$2} /pixelHeight/ {h=$2} /hasAlpha/ {a=$2} END {print w "x" h ", alpha " a}')"
done
exit "$status"
