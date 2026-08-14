//
//  AgentMailClient.swift
//  Minimal AgentMail REST client for the host app and widget extension.
//

import Foundation

enum AgentMailClientError: LocalizedError {
    case notConfigured
    case invalidURL
    case httpStatus(Int, String?)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Add your AgentMail API key and inbox ID in Email Agent settings."
        case .invalidURL:
            return "Could not build the AgentMail request URL."
        case .httpStatus(let code, let body):
            if let body, !body.isEmpty {
                return "AgentMail returned HTTP \(code): \(body)"
            }
            return "AgentMail returned HTTP \(code)."
        case .decoding(let error):
            return "Failed to decode AgentMail response: \(error.localizedDescription)"
        }
    }
}

struct AgentMailClient {
    var baseURL: URL = URL(string: "https://api.agentmail.to")!
    var apiKey: String
    var session: URLSession = .shared

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    static func fromStore(_ store: AgentCredentialsStore = .shared) throws -> AgentMailClient {
        guard let apiKey = store.apiKey, !apiKey.isEmpty else {
            throw AgentMailClientError.notConfigured
        }
        return AgentMailClient(apiKey: apiKey)
    }

    func listMessages(
        inboxId: String,
        limit: Int = 10,
        labels: [String] = []
    ) async throws -> AgentMailListMessagesResponse {
        var pathAllowed = CharacterSet.urlPathAllowed
        pathAllowed.remove(charactersIn: "@")
        let encodedInbox = inboxId.addingPercentEncoding(withAllowedCharacters: pathAllowed) ?? inboxId

        var components = URLComponents()
        components.scheme = baseURL.scheme
        components.host = baseURL.host
        components.port = baseURL.port
        components.percentEncodedPath = "/v0/inboxes/\(encodedInbox)/messages"

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: String(limit))
        ]
        for label in labels {
            queryItems.append(URLQueryItem(name: "labels", value: label))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw AgentMailClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AgentMailClientError.httpStatus(-1, nil)
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            throw AgentMailClientError.httpStatus(http.statusCode, body)
        }

        do {
            return try JSONDecoder.agentMail.decode(AgentMailListMessagesResponse.self, from: data)
        } catch {
            throw AgentMailClientError.decoding(error)
        }
    }

    /// Builds a home-screen snapshot: needs-reply count + recent inbox activity.
    func fetchAgentSnapshot(
        inboxId: String,
        agentDisplayName: String
    ) async throws -> EmailAgentSnapshot {
        async let needsReplyTask = listMessages(
            inboxId: inboxId,
            limit: 50,
            labels: [AgentMailNeedsAttentionLabel.needsReply]
        )
        async let recentTask = listMessages(inboxId: inboxId, limit: 5)

        let needsReply = try await needsReplyTask
        let recent = try await recentTask

        return EmailAgentSnapshot(
            inboxId: inboxId,
            agentDisplayName: agentDisplayName,
            fetchedAt: Date(),
            needsReplyCount: needsReply.count,
            recentMessages: recent.messages,
            statusMessage: needsReply.count == 0 ? "Inbox clear" : "Needs attention"
        )
    }
}
