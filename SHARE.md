# Installing Meeting Alarm

Meeting Alarm is a small macOS **menu-bar app**. It isn't from the App Store and isn't
notarized by Apple yet, so macOS will ask you to confirm it **once**. Here's the whole
process — it takes about a minute.

## 1. Unzip

Double-click `MeetingAlarm-x.y.z.zip` to get **MeetingAlarm.app**, then drag it into your
**Applications** folder (optional, but tidy).

## 2. Open it the first time

A normal double-click will say *"MeetingAlarm can't be opened because the developer cannot
be verified."* That's expected for an app that hasn't been through Apple's paid
notarization — not a sign anything is wrong. To allow it:

**Right-click** (or Control-click) **MeetingAlarm.app → Open**, then click **Open** in the
dialog. You only do this the first time; afterwards it opens with a normal double-click.

> If macOS still refuses (recent versions sometimes hide the Open button): open
> **System Settings → Privacy & Security**, scroll down to the note about MeetingAlarm, and
> click **Open Anyway** — then launch the app again.

**Terminal alternative** (same result, one command):

```
xattr -dr com.apple.quarantine /Applications/MeetingAlarm.app
```

## 3. Grant Calendar access

On first launch macOS asks to let Meeting Alarm read your **Calendar** — click **Allow**.
It reads your events *only* to alarm you before meetings; nothing leaves your Mac. It
picks up any calendar you've added under **System Settings → Internet Accounts** (Google,
iCloud, Exchange, …).

## 4. Use it

There's **no Dock icon** — look for the **bell icon in the menu bar** (top-right of the
screen). Click it, check the meetings you want an extra alarm for, pick a style, and
you're set. **Test Alarm** in the footer fires the overlay right away so you can see and
hear what it does.

---

### Is this safe?

The "unverified developer" warning only means the app wasn't signed through Apple's paid
notarization service — it does not mean the app is unsafe. If you'd rather build it
yourself from source, the project's `README.md` has the steps.

### Removing the warning entirely (for whoever sends this)

Sign the app with an Apple **Developer ID Application** certificate and **notarize** it
(`xcrun notarytool submit` → `xcrun stapler staple`). That requires an Apple Developer
account, after which recipients can just double-click — no warning, no Terminal.
