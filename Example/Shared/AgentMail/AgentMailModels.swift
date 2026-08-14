//
//  AgentMailModels.swift
//  Shared between the host app and EmailAgentWidget.
//

import Foundation

enum AgentMailNeedsAttentionLabel {
    /// Convention used by AI email agents to mark messages awaiting a reply.
    static let needsReply = "needs-reply"
    static let unread = "unread"
}

struct AgentMailMessageSummary: Codable, Hashable, Identifiable {
    let inboxId: String
    let threadId: String
    let messageId: String
    let labels: [String]
    let timestamp: Date
    let from: String
    let to: [String]
    let subject: String?
    let preview: String?

    var id: String { messageId }

    var displaySender: String {
        if let start = from.firstIndex(of: "<"), let end = from.firstIndex(of: ">"), start < end {
            let name = from[..<start].trimmingCharacters(in: .whitespaces)
            return name.isEmpty ? String(from[from.index(after: start)..<end]) : name
        }
        return from
    }

    var needsReply: Bool {
        labels.contains(where: { $0.caseInsensitiveCompare(AgentMailNeedsAttentionLabel.needsReply) == .orderedSame })
    }

    var isUnread: Bool {
        labels.contains(where: { $0.caseInsensitiveCompare(AgentMailNeedsAttentionLabel.unread) == .orderedSame })
    }

    enum CodingKeys: String, CodingKey {
        case inboxId = "inbox_id"
        case threadId = "thread_id"
        case messageId = "message_id"
        case labels
        case timestamp
        case from
        case to
        case subject
        case preview
    }
}

struct AgentMailListMessagesResponse: Codable {
    let count: Int
    let messages: [AgentMailMessageSummary]
    let limit: Int?
    let nextPageToken: String?

    enum CodingKeys: String, CodingKey {
        case count
        case messages
        case limit
        case nextPageToken = "next_page_token"
    }
}

struct AgentMailInbox: Codable, Hashable {
    let inboxId: String
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case inboxId = "inbox_id"
        case displayName = "display_name"
    }
}

struct EmailAgentSnapshot: Codable, Hashable {
    var inboxId: String
    var agentDisplayName: String
    var fetchedAt: Date
    var needsReplyCount: Int
    var recentMessages: [AgentMailMessageSummary]
    var statusMessage: String

    static var placeholder: EmailAgentSnapshot {
        EmailAgentSnapshot(
            inboxId: "agent@example.agentmail.to",
            agentDisplayName: "AI Email Agent",
            fetchedAt: Date(),
            needsReplyCount: 3,
            recentMessages: [
                AgentMailMessageSummary(
                    inboxId: "agent@example.agentmail.to",
                    threadId: "thread_1",
                    messageId: "msg_1",
                    labels: ["needs-reply", "unread"],
                    timestamp: Date().addingTimeInterval(-3600),
                    from: "Alex Rivera <alex@acme.com>",
                    to: ["agent@example.agentmail.to"],
                    subject: "Quote follow-up",
                    preview: "Can you send the revised proposal by Friday?"
                ),
                AgentMailMessageSummary(
                    inboxId: "agent@example.agentmail.to",
                    threadId: "thread_2",
                    messageId: "msg_2",
                    labels: ["needs-reply"],
                    timestamp: Date().addingTimeInterval(-7200),
                    from: "Jordan Lee <jordan@studio.io>",
                    to: ["agent@example.agentmail.to"],
                    subject: "Schedule sync",
                    preview: "Does Tuesday at 2pm still work?"
                )
            ],
            statusMessage: "Demo snapshot"
        )
    }
}
