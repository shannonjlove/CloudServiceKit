//
//  EmailAgentWidget.swift
//  EmailAgentWidget
//

import WidgetKit
import SwiftUI

struct EmailAgentWidget: Widget {
    let kind: String = EmailAgentWidgetKind.id

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EmailAgentTimelineProvider()) { entry in
            EmailAgentWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    EmailAgentPalette.backgroundGradient
                }
        }
        .configurationDisplayName("AI Email Agent")
        .description("See messages that need your agent’s attention.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct EmailAgentWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: EmailAgentEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallEmailAgentWidgetView(entry: entry)
        case .systemMedium:
            MediumEmailAgentWidgetView(entry: entry)
        default:
            LargeEmailAgentWidgetView(entry: entry)
        }
    }
}

enum EmailAgentPalette {
    static let ink = Color(red: 0.07, green: 0.12, blue: 0.14)
    static let seafoam = Color(red: 0.18, green: 0.62, blue: 0.58)
    static let seafoamDeep = Color(red: 0.08, green: 0.38, blue: 0.40)
    static let mist = Color(red: 0.90, green: 0.95, blue: 0.94)
    static let accent = Color(red: 0.95, green: 0.55, blue: 0.22)

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.16, blue: 0.18),
                Color(red: 0.08, green: 0.28, blue: 0.30),
                Color(red: 0.12, green: 0.36, blue: 0.34)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct SmallEmailAgentWidgetView: View {
    let entry: EmailAgentEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(EmailAgentPalette.seafoam)
                    .frame(width: 8, height: 8)
                Text(entry.snapshot.agentDisplayName)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(EmailAgentPalette.mist)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text("\(entry.snapshot.needsReplyCount)")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)

            Text(statusLabel)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(EmailAgentPalette.mist.opacity(0.85))
                .lineLimit(2)
        }
        .padding(16)
        .widgetURL(URL(string: "\(AgentAppGroup.deepLinkScheme)://inbox"))
    }

    private var statusLabel: String {
        switch entry.configurationState {
        case .needsSetup:
            return "Tap to connect AgentMail"
        case .error:
            return "Using cached inbox"
        case .ready:
            return entry.snapshot.needsReplyCount == 1 ? "needs reply" : "need reply"
        }
    }
}

struct MediumEmailAgentWidgetView: View {
    let entry: EmailAgentEntry

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.snapshot.agentDisplayName)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(EmailAgentPalette.mist)
                    .lineLimit(1)

                Text("\(entry.snapshot.needsReplyCount)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(bannerText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(EmailAgentPalette.accent)
                    .lineLimit(2)

                Spacer(minLength: 0)
            }
            .frame(width: 110, alignment: .leading)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(entry.snapshot.recentMessages.prefix(2))) { message in
                    MessageRowView(message: message)
                }
                if entry.snapshot.recentMessages.isEmpty {
                    Text("No recent messages")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(EmailAgentPalette.mist.opacity(0.7))
                }
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .widgetURL(URL(string: "\(AgentAppGroup.deepLinkScheme)://inbox"))
    }

    private var bannerText: String {
        switch entry.configurationState {
        case .needsSetup:
            return "Connect AgentMail"
        case .error(let message):
            return message
        case .ready:
            return entry.snapshot.statusMessage
        }
    }
}

struct LargeEmailAgentWidgetView: View {
    let entry: EmailAgentEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.snapshot.agentDisplayName)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(EmailAgentPalette.mist)
                    Text(entry.snapshot.inboxId)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(EmailAgentPalette.mist.opacity(0.65))
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(entry.snapshot.needsReplyCount)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("needs reply")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(EmailAgentPalette.seafoam)
                }
            }

            Rectangle()
                .fill(EmailAgentPalette.seafoam.opacity(0.25))
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(entry.snapshot.recentMessages.prefix(4))) { message in
                    MessageRowView(message: message, showsPreview: true)
                }
                if entry.snapshot.recentMessages.isEmpty {
                    Text("Your agent inbox is quiet.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(EmailAgentPalette.mist.opacity(0.7))
                }
            }

            Spacer(minLength: 0)

            Text(footerText)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(EmailAgentPalette.mist.opacity(0.55))
        }
        .padding(18)
        .widgetURL(URL(string: "\(AgentAppGroup.deepLinkScheme)://inbox"))
    }

    private var footerText: String {
        switch entry.configurationState {
        case .needsSetup:
            return "Open the app to add your AgentMail API key."
        case .error(let message):
            return message
        case .ready:
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return "Updated \(formatter.localizedString(for: entry.snapshot.fetchedAt, relativeTo: Date()))"
        }
    }
}

struct MessageRowView: View {
    let message: AgentMailMessageSummary
    var showsPreview: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(message.needsReply ? EmailAgentPalette.accent : EmailAgentPalette.seafoam)
                .frame(width: 3, height: showsPreview ? 34 : 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(message.displaySender)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(shortTime)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(EmailAgentPalette.mist.opacity(0.55))
                }
                Text(message.subject ?? "(no subject)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(EmailAgentPalette.mist.opacity(0.9))
                    .lineLimit(1)
                if showsPreview, let preview = message.preview, !preview.isEmpty {
                    Text(preview)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(EmailAgentPalette.mist.opacity(0.6))
                        .lineLimit(1)
                }
            }
        }
    }

    private var shortTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: message.timestamp)
    }
}

#if DEBUG
struct EmailAgentWidget_Previews: PreviewProvider {
    static var previews: some View {
        EmailAgentWidgetView(
            entry: EmailAgentEntry(date: Date(), snapshot: .placeholder, configurationState: .ready)
        )
        .previewContext(WidgetPreviewContext(family: .systemSmall))

        EmailAgentWidgetView(
            entry: EmailAgentEntry(date: Date(), snapshot: .placeholder, configurationState: .ready)
        )
        .previewContext(WidgetPreviewContext(family: .systemMedium))

        EmailAgentWidgetView(
            entry: EmailAgentEntry(date: Date(), snapshot: .placeholder, configurationState: .ready)
        )
        .previewContext(WidgetPreviewContext(family: .systemLarge))
    }
}
#endif
