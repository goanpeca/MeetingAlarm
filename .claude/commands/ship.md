---
description: Verify the full gate, then build, sign, and relaunch MeetingAlarm.app
---
Build and relaunch the app after verifying the harness gate. Do NOT commit or push unless
explicitly asked.

1. Run `make ci`. If anything fails, stop and report — do not build a broken app.
2. Run `make app` (assembles + signs with the stable "MeetingAlarm Dev" identity). If a
   macOS keychain dialog appears ("codesign wants to use key MeetingAlarm Dev"), tell the
   user to click **Always Allow** — needed once, and it keeps the Calendar (TCC) permission
   across rebuilds. If signing falls back to ad-hoc, say so (it resets the Calendar grant).
3. Relaunch: `pkill -x MeetingAlarm 2>/dev/null; sleep 0.5; open MeetingAlarm.app`.
4. Report what changed and confirm the gate passed.
