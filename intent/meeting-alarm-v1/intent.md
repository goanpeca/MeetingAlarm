# Intent — Meeting Alarm v1

**Status:** approved · **Spec:** [spec.md](spec.md) · **Plan:** [plan.md](plan.md)

## Problem

People who lose track of time in focused work miss meetings despite ordinary calendar
notifications, which are easy to dismiss or never seen.

## Who it's for

Anyone who works heads-down at a Mac and needs an alert they cannot overlook — including people
with sensory sensitivities who need a predictable, non-startling option.

## What success looks like

An always-on macOS menu-bar app that makes meetings **impossible to miss while you're at the
computer**: arm an extra, unmissable alarm on any upcoming meeting and, at the chosen moment, it
throws a full-screen overlay across every display with an optional sound.

## Design values / constraints

- Two presets: **Blast** (max-intensity) and the sensory-safe **Gentle Ramp**.
- Honors Reduce Motion; **Esc always dismisses** — it alerts forcefully without ever trapping
  the user.

## Non-goals

Being a calendar client; phone/remote notifications; team scheduling.
