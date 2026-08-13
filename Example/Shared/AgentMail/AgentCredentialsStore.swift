//
//  AgentCredentialsStore.swift
//  Shared App Group storage for AgentMail credentials and cached snapshot.
//

import Foundation
import WidgetKit

enum AgentAppGroup {
    static let identifier = "group.me.shuifeng.CloudServiceKitExample.emailagent"
    static let deepLinkScheme = "emailagent"
}

enum AgentCredentialKey {
    static let apiKey = "agentmail.apiKey"
    static let inboxId = "agentmail.inboxId"
    static let agentDisplayName = "agentmail.displayName"
    static let snapshot = "agentmail.snapshot"
}

final class AgentCredentialsStore {
    static let shared = AgentCredentialsStore()

    private let defaults: UserDefaults?

    init(suiteName: String = AgentAppGroup.identifier) {
        defaults = UserDefaults(suiteName: suiteName)
    }

    var apiKey: String? {
        get { defaults?.string(forKey: AgentCredentialKey.apiKey) }
        set {
            defaults?.set(newValue, forKey: AgentCredentialKey.apiKey)
            defaults?.synchronize()
        }
    }

    var inboxId: String? {
        get { defaults?.string(forKey: AgentCredentialKey.inboxId) }
        set {
            defaults?.set(newValue, forKey: AgentCredentialKey.inboxId)
            defaults?.synchronize()
        }
    }

    var agentDisplayName: String {
        get { defaults?.string(forKey: AgentCredentialKey.agentDisplayName) ?? "AI Email Agent" }
        set {
            defaults?.set(newValue, forKey: AgentCredentialKey.agentDisplayName)
            defaults?.synchronize()
        }
    }

    var isConfigured: Bool {
        guard let apiKey, !apiKey.isEmpty, let inboxId, !inboxId.isEmpty else { return false }
        return true
    }

    func saveSnapshot(_ snapshot: EmailAgentSnapshot) {
        guard let data = try? JSONEncoder.agentMail.encode(snapshot) else { return }
        defaults?.set(data, forKey: AgentCredentialKey.snapshot)
        defaults?.synchronize()
    }

    func loadSnapshot() -> EmailAgentSnapshot? {
        guard let data = defaults?.data(forKey: AgentCredentialKey.snapshot) else { return nil }
        return try? JSONDecoder.agentMail.decode(EmailAgentSnapshot.self, from: data)
    }

    func clear() {
        defaults?.removeObject(forKey: AgentCredentialKey.apiKey)
        defaults?.removeObject(forKey: AgentCredentialKey.inboxId)
        defaults?.removeObject(forKey: AgentCredentialKey.agentDisplayName)
        defaults?.removeObject(forKey: AgentCredentialKey.snapshot)
        defaults?.synchronize()
    }

    func reloadWidgets() {
        if #available(iOSApplicationExtension 14.0, iOS 14.0, *) {
            WidgetCenter.shared.reloadTimelines(ofKind: EmailAgentWidgetKind.id)
        }
    }
}

extension JSONDecoder {
    static let agentMail: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = ISO8601DateFormatter.agentMailFractional.date(from: value)
                ?? ISO8601DateFormatter.agentMail.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(value)")
        }
        return decoder
    }()
}

extension JSONEncoder {
    static let agentMail: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

extension ISO8601DateFormatter {
    static let agentMail: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let agentMailFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

enum EmailAgentWidgetKind {
    static let id = "EmailAgentWidget"
}
