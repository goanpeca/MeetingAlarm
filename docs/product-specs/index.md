# Product Specs

What the product is for and who it serves. (Product-level intent lives here; per-subsystem
*design* lives in [`../design-docs/`](../design-docs/index.md).)

## Meeting Alarm

An always-on macOS menu-bar app that makes meetings **impossible to miss while you're at the
computer**: arm an extra, unmissable alarm on any upcoming meeting and, at the chosen moment,
it throws a full-screen overlay across every display with an optional sound.

- **Who it's for** — people who lose track of time in focused work and miss meetings despite
  ordinary calendar notifications.
- **Design value** — two presets, **Blast** (max-intensity) and the sensory-safe **Gentle
  Ramp**; the alarm honors Reduce Motion and **Esc always dismisses**, so it can alert
  forcefully without ever trapping the user.
