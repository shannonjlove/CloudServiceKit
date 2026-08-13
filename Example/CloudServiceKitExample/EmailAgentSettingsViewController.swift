//
//  EmailAgentSettingsViewController.swift
//  CloudServiceKitExample
//
//  Configure AgentMail credentials shared with the home-screen widget.
//

import UIKit
import WidgetKit

final class EmailAgentSettingsViewController: UITableViewController {
    private enum Field: Int, CaseIterable {
        case displayName
        case inboxId
        case apiKey
    }

    private let store = AgentCredentialsStore.shared
    private var displayName: String
    private var inboxId: String
    private var apiKey: String
    private var statusText = "Enter your AgentMail API key and inbox, then save."
    private var isSaving = false

    init() {
        displayName = store.agentDisplayName
        inboxId = store.inboxId ?? ""
        apiKey = store.apiKey ?? ""
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "AI Email Agent"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Save",
            style: .done,
            target: self,
            action: #selector(saveTapped)
        )
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "field")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "status")
        tableView.keyboardDismissMode = .onDrag
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 3 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return Field.allCases.count
        case 1: return 1
        default: return 2
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "AgentMail"
        case 1: return "Status"
        default: return "Widget"
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Credentials are stored in the App Group so the widget can refresh without opening the app. Prefer a scoped AgentMail API key."
        case 2:
            return "Long-press the Home Screen → Widgets → AI Email Agent. Messages labeled needs-reply drive the attention count."
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "field", for: indexPath)
            cell.selectionStyle = .none
            cell.contentConfiguration = nil
            for subview in cell.contentView.subviews { subview.removeFromSuperview() }

            let field = UITextField(frame: .zero)
            field.translatesAutoresizingMaskIntoConstraints = false
            field.clearButtonMode = .whileEditing
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
            field.tag = indexPath.row
            field.addTarget(self, action: #selector(textChanged(_:)), for: .editingChanged)

            switch Field(rawValue: indexPath.row) {
            case .displayName:
                field.placeholder = "Display name"
                field.text = displayName
                field.isSecureTextEntry = false
            case .inboxId:
                field.placeholder = "Inbox ID (agent@yourdomain.agentmail.to)"
                field.text = inboxId
                field.keyboardType = .emailAddress
                field.isSecureTextEntry = false
            case .apiKey:
                field.placeholder = "AgentMail API key"
                field.text = apiKey
                field.isSecureTextEntry = true
            case .none:
                break
            }

            cell.contentView.addSubview(field)
            NSLayoutConstraint.activate([
                field.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),
                field.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
                field.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 10),
                field.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -10)
            ])
            return cell
        }

        if indexPath.section == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "status", for: indexPath)
            var config = cell.defaultContentConfiguration()
            config.text = statusText
            config.textProperties.numberOfLines = 0
            config.textProperties.color = .secondaryLabel
            cell.contentConfiguration = config
            cell.selectionStyle = .none
            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: "status", for: indexPath)
        var config = cell.defaultContentConfiguration()
        if indexPath.row == 0 {
            config.text = "Refresh Widget Now"
            config.textProperties.color = .systemBlue
        } else {
            config.text = "Clear Credentials"
            config.textProperties.color = .systemRed
        }
        cell.contentConfiguration = config
        cell.selectionStyle = .default
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 2 else { return }
        if indexPath.row == 0 {
            refreshWidget()
        } else {
            clearCredentials()
        }
    }

    @objc private func textChanged(_ field: UITextField) {
        switch Field(rawValue: field.tag) {
        case .displayName:
            displayName = field.text ?? ""
        case .inboxId:
            inboxId = field.text ?? ""
        case .apiKey:
            apiKey = field.text ?? ""
        case .none:
            break
        }
    }

    @objc private func saveTapped() {
        guard !isSaving else { return }
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedInbox = inboxId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedKey.isEmpty, !trimmedInbox.isEmpty else {
            statusText = "API key and inbox ID are required."
            tableView.reloadSections(IndexSet(integer: 1), with: .none)
            return
        }

        isSaving = true
        statusText = "Checking AgentMail…"
        tableView.reloadSections(IndexSet(integer: 1), with: .none)
        navigationItem.rightBarButtonItem?.isEnabled = false

        store.apiKey = trimmedKey
        store.inboxId = trimmedInbox
        store.agentDisplayName = trimmedName.isEmpty ? "AI Email Agent" : trimmedName

        Task { @MainActor in
            defer {
                self.isSaving = false
                self.navigationItem.rightBarButtonItem?.isEnabled = true
            }
            do {
                let client = try AgentMailClient.fromStore(self.store)
                let snapshot = try await client.fetchAgentSnapshot(
                    inboxId: trimmedInbox,
                    agentDisplayName: self.store.agentDisplayName
                )
                self.store.saveSnapshot(snapshot)
                self.store.reloadWidgets()
                self.statusText = "Connected. \(snapshot.needsReplyCount) message(s) need a reply."
            } catch {
                self.statusText = error.localizedDescription
            }
            self.tableView.reloadSections(IndexSet(integer: 1), with: .none)
        }
    }

    private func refreshWidget() {
        store.reloadWidgets()
        statusText = "Requested a widget timeline reload."
        tableView.reloadSections(IndexSet(integer: 1), with: .none)
    }

    private func clearCredentials() {
        store.clear()
        displayName = "AI Email Agent"
        inboxId = ""
        apiKey = ""
        statusText = "Credentials cleared."
        tableView.reloadData()
        store.reloadWidgets()
    }
}
