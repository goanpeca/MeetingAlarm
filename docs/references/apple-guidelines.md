# Apple & Swift guidelines

Official guidance this app is designed and reviewed against. Use it as the checklist for UI,
accessibility, and release work (e.g. the HIG pass and a11y audit), and cite the relevant row
in review findings. Links verified 2026-10-30.

## Human Interface Guidelines (macOS)

| Topic | Guideline | Applies to |
| --- | --- | --- |
| Menu bar apps ("menu bar extras") | [The menu bar](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar) | Status item, popover, template icon |
| Platform overview | [Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos) | Whole app |
| Settings | [Settings](https://developer.apple.com/design/human-interface-guidelines/settings) | Settings window (⌘,) |
| Popovers | [Popovers](https://developer.apple.com/design/human-interface-guidelines/popovers) | Menu popover |
| Panels | [Panels](https://developer.apple.com/design/human-interface-guidelines/panels) | Quick panel |
| Alerts | [Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts) | Overlay, quit confirmation |
| Onboarding | [Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding) | First-run flow |
| Privacy | [Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy) | Calendar permission prompt and copy |
| Accessibility | [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) | VoiceOver, contrast, Dynamic Type |
| Motion | [Motion](https://developer.apple.com/design/human-interface-guidelines/motion) | Overlay effects, Reduce Motion |
| Keyboards | [Keyboards](https://developer.apple.com/design/human-interface-guidelines/keyboards) | Shortcuts, Esc, global hotkey |
| SF Symbols | [SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols) | Menu-bar and in-app icons |
| App icons | [App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons) | `Resources/AppIcon.icns` |
| Dark Mode | [Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode) | All colors |

## Platform APIs

| Topic | Reference | Used in |
| --- | --- | --- |
| Menu bar scene | [`MenuBarExtra`](https://developer.apple.com/documentation/swiftui/menubarextra) | `App.swift` |
| Status items | [`NSStatusItem`](https://developer.apple.com/documentation/appkit/nsstatusitem) | AppKit layer under `MenuBarExtra` |
| Agent (no Dock icon) | [`LSUIElement`](https://developer.apple.com/documentation/bundleresources/information-property-list/lsuielement) | `Resources/Info.plist` |
| Calendar access | [Accessing the event store](https://developer.apple.com/documentation/eventkit/accessing-the-event-store) | `Calendar/EventKitSource.swift` |
| Launch at login | [`SMAppService`](https://developer.apple.com/documentation/servicemanagement/smappservice) | `LoginItem.swift` |
| Logging | [`Logger`](https://developer.apple.com/documentation/os/logger) | `Logging.swift` (no `print`) |
| Localization | [String catalogs](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog) | User-facing strings |

## Distribution

| Topic | Reference |
| --- | --- |
| Notarization | [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) |
| Hardened runtime | [Hardened Runtime](https://developer.apple.com/documentation/security/hardened-runtime) |
| Privacy manifest | [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files) |

## Swift

| Topic | Reference |
| --- | --- |
| Naming and API shape | [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) |
| Strict concurrency (Swift 6) | [Swift 6 migration guide](https://www.swift.org/migration/documentation/migrationguide/) |
| Tests | [Swift Testing](https://developer.apple.com/documentation/testing) |
