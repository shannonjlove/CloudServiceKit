//
//  StorageSettingsViewController.swift
//  CloudServiceKitExample
//

import UIKit

/// Lists every cloud / rclone remote and lets you enter the credentials the
/// Drive Browser needs to connect.
class StorageSettingsViewController: UIViewController {
    
    private var tableView: UITableView!
    
    private var observer: NSObjectProtocol?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Storage Connections"
        view.backgroundColor = .systemBackground
        tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(tableView)
        
        observer = NotificationCenter.default.addObserver(
            forName: CloudConfigurationStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.tableView.reloadData()
        }
    }
    
    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

extension StorageSettingsViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 1 : CloudDriveType.allCases.count - 1
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "Rclone Browser" : "OAuth Cloud Drives"
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 0 {
            return "Connect this app to an rclone Remote Control server (rclone rcd or rclone Web GUI). The RC server already holds your remotes — Google Drive, IDrive e2, Koofr, S3, and any other rclone storage."
        }
        return "Register an app with each provider, then paste the client id, secret, and redirect URL. The example URL scheme is oauth-swift://oauth-callback."
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let drive = drive(at: indexPath)
        var content = UIListContentConfiguration.subtitleCell()
        content.image = drive.image
        content.text = drive.title
        let configured = CloudConfigurationStore.shared.configuration(for: drive) != nil
        content.secondaryText = configured ? "Connected — tap to edit" : "Not configured — tap to add credentials"
        content.secondaryTextProperties.color = configured ? .secondaryLabel : .systemOrange
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let drive = drive(at: indexPath)
        let vc = CloudProviderConfigViewController(drive: drive)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func drive(at indexPath: IndexPath) -> CloudDriveType {
        if indexPath.section == 0 {
            return .rclone
        }
        return CloudDriveType.allCases.filter { $0 != .rclone }[indexPath.row]
    }
}

final class CloudProviderConfigViewController: UIViewController {
    
    private let drive: CloudDriveType
    
    private let appIdField = UITextField()
    private let appSecretField = UITextField()
    private let redirectField = UITextField()
    
    init(drive: CloudDriveType) {
        self.drive = drive
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = drive.title
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Save", style: .done, target: self, action: #selector(save))
        
        let draft = CloudConfigurationStore.shared.draft(for: drive)
        configure(appIdField, text: draft.appId, placeholder: drive.appIdPlaceholder, secure: false)
        configure(appSecretField, text: draft.appSecret, placeholder: drive.appSecretPlaceholder, secure: true)
        configure(redirectField, text: draft.redirectUrl, placeholder: drive.redirectPlaceholder, secure: false)
        redirectField.keyboardType = drive == .rclone ? .URL : .URL
        redirectField.autocapitalizationType = .none
        redirectField.autocorrectionType = .no
        appIdField.autocapitalizationType = .none
        appIdField.autocorrectionType = .no
        
        let stack = UIStackView(arrangedSubviews: [
            labeled(drive.appIdLabel, field: appIdField),
            labeled(drive.appSecretLabel, field: appSecretField),
            labeled(drive.redirectLabel, field: redirectField)
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        
        let help = UILabel()
        help.numberOfLines = 0
        help.font = .preferredFont(forTextStyle: .footnote)
        help.textColor = .secondaryLabel
        help.text = drive.configurationHelp
        help.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(help)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            help.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 20),
            help.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            help.trailingAnchor.constraint(equalTo: stack.trailingAnchor)
        ])
    }
    
    @objc private func save() {
        let config = CloudConfiguration(
            appId: appIdField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            appSecret: appSecretField.text ?? "",
            redirectUrl: redirectField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        )
        if !config.isConfigured(for: drive) {
            let alert = UIAlertController(
                title: "Missing fields",
                message: drive == .rclone
                    ? "Enter the rclone Remote Control URL (for example https://rclone-mcp.shannonjlove.cloud or http://127.0.0.1:5572)."
                    : "Enter app id, app secret, and redirect URL.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        CloudConfigurationStore.shared.save(config, for: drive)
        navigationController?.popViewController(animated: true)
    }
    
    private func configure(_ field: UITextField, text: String, placeholder: String, secure: Bool) {
        field.text = text
        field.placeholder = placeholder
        field.borderStyle = .roundedRect
        field.isSecureTextEntry = secure
        field.clearButtonMode = .whileEditing
        field.autocorrectionType = .no
    }
    
    private func labeled(_ title: String, field: UITextField) -> UIView {
        let label = UILabel()
        label.text = title
        label.font = .preferredFont(forTextStyle: .caption1)
        label.textColor = .secondaryLabel
        let stack = UIStackView(arrangedSubviews: [label, field])
        stack.axis = .vertical
        stack.spacing = 6
        return stack
    }
}
