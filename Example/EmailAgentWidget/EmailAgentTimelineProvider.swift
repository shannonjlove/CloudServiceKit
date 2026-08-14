//
//  EmailAgentTimelineProvider.swift
//  EmailAgentWidget
//

import WidgetKit
import SwiftUI

struct EmailAgentEntry: TimelineEntry {
    let date: Date
    let snapshot: EmailAgentSnapshot
    let configurationState: ConfigurationState

    enum ConfigurationState {
        case ready
        case needsSetup
        case error(String)
    }
}

struct EmailAgentTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> EmailAgentEntry {
        EmailAgentEntry(date: Date(), snapshot: .placeholder, configurationState: .ready)
    }

    func getSnapshot(in context: Context, completion: @escaping (EmailAgentEntry) -> Void) {
        if context.isPreview {
            completion(EmailAgentEntry(date: Date(), snapshot: .placeholder, configurationState: .ready))
            return
        }
        Task {
            let entry = await loadEntry()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EmailAgentEntry>) -> Void) {
        Task {
            let entry = await loadEntry()
            let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
            completion(Timeline(entries: [entry], policy: .after(refresh)))
        }
    }

    private func loadEntry() async -> EmailAgentEntry {
        let store = AgentCredentialsStore.shared
        guard store.isConfigured, let inboxId = store.inboxId else {
            let cached = store.loadSnapshot() ?? .placeholder
            return EmailAgentEntry(date: Date(), snapshot: cached, configurationState: .needsSetup)
        }

        do {
            let client = try AgentMailClient.fromStore(store)
            let snapshot = try await client.fetchAgentSnapshot(
                inboxId: inboxId,
                agentDisplayName: store.agentDisplayName
            )
            store.saveSnapshot(snapshot)
            return EmailAgentEntry(date: Date(), snapshot: snapshot, configurationState: .ready)
        } catch {
            if let cached = store.loadSnapshot() {
                return EmailAgentEntry(
                    date: Date(),
                    snapshot: cached,
                    configurationState: .error(error.localizedDescription)
                )
            }
            return EmailAgentEntry(
                date: Date(),
                snapshot: .placeholder,
                configurationState: .error(error.localizedDescription)
            )
        }
    }
}
