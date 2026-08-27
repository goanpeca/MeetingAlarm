# Design Docs Index

Catalog of design documents. **Verification status** is one of `current` (reflects the code as
built), `stale` (may lag the code — re-verify before trusting), or `superseded` (replaced by a
later doc, kept for history).

| Date       | Document | Scope | Status |
|------------|----------|-------|--------|
| 2026-08-26 | [meeting-alarm — Design Spec](2026-08-26-meeting-alarm-design.md) | **v1 baseline**: menu-bar alerter, dual calendar sources (multi-account Google), sensory-profile overlay, snooze scheduling, repo/harness + quality tooling | current |
| 2026-08-27 | [Post-v1 Subsystems](2026-08-27-post-v1-subsystems.md) | Recurring-series arming, global hot key + quick panel, launch-at-login, accessibility/keyboard, color-panel + accent, harness additions | current |

> When code diverges from a `current` doc, either update the doc or mark it `stale` here in the
> same change. Do not let a `current` doc silently drift.
