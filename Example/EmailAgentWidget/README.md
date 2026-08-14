# AI Email Agent Widget

Home Screen widget for your AgentMail-powered AI email agent.

## What it shows

- **Small** — needs-reply count and agent name
- **Medium** — count plus the two latest messages
- **Large** — inbox identity, needs-reply count, and up to four recent messages

Messages labeled `needs-reply` drive the attention count (AgentMail has no built-in unread flag).

## Setup in Xcode

1. Open `Example/CloudServiceKitExample.xcworkspace`.
2. Select the **CloudServiceKitExample** and **EmailAgentWidget** targets.
3. Enable the App Group `group.me.shuifeng.CloudServiceKitExample.emailagent` for both targets in Signing & Capabilities (already declared in entitlements).
4. Build and run on an **iOS 17+** device or simulator (widget target deployment).
5. In the app, tap **Email Agent**, enter:
   - Agent display name
   - Inbox ID (for example `support@yourdomain.agentmail.to`)
   - AgentMail API key (`Bearer` auth)
6. Tap **Save** — the app verifies the inbox, caches a snapshot in the App Group, and reloads the widget.
7. Long-press the Home Screen → **Widgets** → add **AI Email Agent**.

## Architecture

| Path | Role |
|------|------|
| `Shared/AgentMail/` | Models, App Group credential store, AgentMail REST client |
| `EmailAgentWidget/` | WidgetKit extension (timeline + SwiftUI views) |
| `CloudServiceKitExample/EmailAgentSettingsViewController.swift` | In-app credential + refresh UI |

The widget refreshes about every 15 minutes (system may coalesce). Tap the widget to open Email Agent settings via the `emailagent://` URL scheme.

## Security notes

- Prefer a scoped AgentMail API key with the least privileges your agent needs.
- Credentials live in the shared App Group `UserDefaults` so the extension can refresh offline from cache if a network call fails.
- Treat inbound email content shown on the widget as untrusted data.
