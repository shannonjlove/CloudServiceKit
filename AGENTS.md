# AGENTS.md

## Project overview

CloudServiceKit is an **iOS/tvOS** Swift package that wraps several cloud drive
services (Aliyun Drive, Baidu Pan, Box, Dropbox, Google Drive, OneDrive, pCloud,
115, 123) behind a common OAuth2-based API. The library depends on
[OAuthSwift](https://github.com/OAuthSwift/OAuthSwift) and uses Apple-only
frameworks (`UIKit`, `CryptoKit`, `AuthenticationServices`).

- Library sources: `Sources/`
- Example iOS app: `Example/` (Xcode project + CocoaPods)
- Package manifest: `Package.swift` (SwiftPM), `CloudServiceKit.podspec` (CocoaPods)

## Building and running

Building and running the library and the `Example` app require **macOS with
Xcode** (targets iOS 13+ / tvOS 14+):

- Open `Example/` in Xcode, or build the SwiftPM package on macOS.
- Fill in cloud provider app credentials in
  `Example/CloudServiceKitExample/CloudConfiguration.swift` before running the
  example (see `README.md`).

## Cursor Cloud specific instructions

Cursor Cloud Agents run on **Linux (Ubuntu 24.04, x86_64)**, where this
iOS/tvOS library **cannot be compiled or run**: `OAuthSwift`, plus the library's
own `UIKit` / `CryptoKit` / `AuthenticationServices` usage, are Apple-only. A
`swift build` on Linux is therefore expected to fail (e.g. `cannot find type
'NSExtensionContext'`, "Objective-C interoperability is disabled"). This is a
platform limitation, not an environment defect — do not "fix" it by editing
source to strip Apple frameworks.

The environment (`.cursor/environment.json` + `.cursor/setup.sh`) installs the
upstream Swift toolchain (Swift 6.3.3 via `swiftly`) so agents can still work
productively on Linux. What works and what does not:

| Task | Linux Cloud Agent |
| --- | --- |
| `swift --version` | Works (6.3.3) |
| `swift package resolve` | Works (fetches deps pinned by `Package.resolved`) |
| `swift package describe` | Works |
| Editing / navigating `Sources/` | Works |
| `swift build`, running tests, `Example` app | Not supported (needs macOS + Xcode) |

Notes for agents:

- `swift` is on `PATH` in new shells (wired via `.profile` and `.bashrc`). If a
  shell lacks it, run `. "$HOME/.local/share/swiftly/env.sh"`.
- Do not commit `Package.resolved` changes produced on Linux: `swift package
  resolve` rewrites it with OAuthSwift's Linux-only transitive dependencies
  (swift-crypto, Swifter, Kanna, Erik, FileKit, BrightFutures). `.cursor/setup.sh`
  already restores the committed file after resolving.
- Validate iOS/tvOS-affecting changes on macOS + Xcode before relying on them;
  Linux verification is limited to resolution, package inspection, and review of
  the Swift sources.
