#!/usr/bin/env bash
# End-to-end notification verification on a running Android emulator/device.
set -euo pipefail

PKG=com.habitapp.habit_tracker
ACTIVITY=$PKG/.MainActivity
APK="${1:-build/app/outputs/flutter-apk/app-debug.apk}"
ADB="${ADB:-adb}"

log() { echo "[notif-e2e] $*"; }
fail() { echo "[notif-e2e] FAIL: $*" >&2; exit 1; }

has_active_test_notification() {
  local dump
  dump="$("$ADB" shell dumpsys notification --noredact 2>/dev/null || "$ADB" shell dumpsys notification)"
  echo "$dump" | grep -Eqi "Test notification|Scheduled test|Mindfulness"
}

"$ADB" wait-for-device
log "Installing $APK"
"$ADB" install -r "$APK" >/dev/null

log "Granting notification + exact-alarm permissions"
"$ADB" shell pm grant "$PKG" android.permission.POST_NOTIFICATIONS || true
"$ADB" shell appops set "$PKG" SCHEDULE_EXACT_ALARM allow || true
"$ADB" shell dumpsys deviceidle whitelist +"$PKG" >/dev/null || true

log "Cold start once to create app data"
"$ADB" shell am force-stop "$PKG" || true
"$ADB" shell am start -W -n "$ACTIVITY" >/dev/null
sleep 6

log "Mark onboarding complete"
PREFS_TMP="$(mktemp)"
cat > "$PREFS_TMP" <<'EOF'
<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
  <boolean name="flutter.onboarding_complete" value="true" />
  <boolean name="flutter.notif_daily" value="true" />
  <boolean name="flutter.notif_atrisk" value="true" />
  <boolean name="flutter.notif_repair" value="true" />
  <boolean name="flutter.notif_milestone" value="true" />
</map>
EOF
"$ADB" push "$PREFS_TMP" /data/local/tmp/FlutterSharedPreferences.xml >/dev/null
"$ADB" shell run-as "$PKG" mkdir -p shared_prefs
"$ADB" shell run-as "$PKG" cp /data/local/tmp/FlutterSharedPreferences.xml shared_prefs/FlutterSharedPreferences.xml
rm -f "$PREFS_TMP"

log "TEST 1: immediate show via launch extra"
"$ADB" shell am force-stop "$PKG"
"$ADB" shell cmd notification dismiss_all >/dev/null 2>&1 || true
"$ADB" shell am start -W -n "$ACTIVITY" --es notif_test show >/dev/null
sleep 8

if has_active_test_notification; then
  log "PASS: immediate test notification is visible in NotificationManager"
else
  "$ADB" shell dumpsys notification | grep -A3 -i "habitapp\|Test notification\|Scheduled test" | head -40 || true
  fail "immediate test notification not found"
fi

log "Clear notifications before schedule test"
"$ADB" shell cmd notification dismiss_all >/dev/null 2>&1 || true

log "TEST 2: schedule 1-minute notification"
"$ADB" shell am force-stop "$PKG"
"$ADB" shell am start -W -n "$ACTIVITY" --es notif_test schedule >/dev/null
sleep 10
"$ADB" shell input keyevent KEYCODE_HOME || true
log "Waiting 70s for scheduled notification..."
sleep 70

if has_active_test_notification; then
  log "PASS: scheduled test notification fired after ~1 minute"
else
  "$ADB" shell dumpsys notification | grep -A5 -i "habitapp\|Scheduled test\|Test notification" | head -60 || true
  "$ADB" shell dumpsys alarm | grep -A2 -i habitapp | head -40 || true
  fail "scheduled test notification did not fire"
fi

log "Clear notifications before mindfulness tests"
"$ADB" shell cmd notification dismiss_all >/dev/null 2>&1 || true

log "TEST 3: mindfulness preview via launch extra"
"$ADB" shell am force-stop "$PKG"
"$ADB" shell am start -W -n "$ACTIVITY" --es notif_test mindfulness_show >/dev/null
sleep 8

if has_active_test_notification; then
  log "PASS: mindfulness preview is visible in NotificationManager"
else
  "$ADB" shell dumpsys notification | grep -A3 -i "habitapp\|Mindfulness" | head -40 || true
  fail "mindfulness preview notification not found"
fi

log "Clear notifications before mindfulness schedule test"
"$ADB" shell cmd notification dismiss_all >/dev/null 2>&1 || true

log "TEST 4: mindfulness schedule 1-minute notification"
"$ADB" shell am force-stop "$PKG"
"$ADB" shell am start -W -n "$ACTIVITY" --es notif_test mindfulness_schedule >/dev/null
sleep 10
"$ADB" shell input keyevent KEYCODE_HOME || true
log "Waiting 70s for mindfulness scheduled notification..."
sleep 70

if has_active_test_notification; then
  log "PASS: mindfulness scheduled notification fired after ~1 minute"
else
  "$ADB" shell dumpsys notification | grep -A5 -i "habitapp\|Mindfulness" | head -60 || true
  "$ADB" shell dumpsys alarm | grep -A2 -i habitapp | head -40 || true
  fail "mindfulness scheduled notification did not fire"
fi

log "ALL EMULATOR NOTIFICATION TESTS PASSED"
exit 0
