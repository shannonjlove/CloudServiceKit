//
//  ViewController.swift
//  CloudServiceKitExample
//
//  Created by alexiscn on 2021/9/18.
//

import UIKit
import CloudServiceKit
import OAuthSwift

class ViewController: UIViewController {

    enum Section {
        case main
        case saved
    }
    
    enum Item: Hashable {
        case provider(CloudDriveType)
        case cached(CloudAccount)
        
        func hash(into hasher: inout Hasher) {
            switch self {
            case .cached(let account):
                hasher.combine(account.identifier)
            case .provider(let type):
                hasher.combine(type)
            }
        }
    }
    
    private var collectionView: UICollectionView!
    
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    
    private var connector: CloudServiceConnector?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        navigationItem.title = "CloudServiceKit"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "externaldrive.badge.plus"),
            style: .plain,
            target: self,
            action: #selector(openStorageSettings)
        )
        setupCollectionView()
        setupDataSource()
        applyInitialSnapshot()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConfigurationChange),
            name: CloudConfigurationStore.didChangeNotification,
            object: nil
        )
    }
    
    @objc private func openStorageSettings() {
        let vc = StorageSettingsViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func handleConfigurationChange() {
        applyInitialSnapshot()
    }

    private func connect(_ drive: CloudDriveType) {
        if drive == .rclone {
            connectRclone()
            return
        }
        
        guard CloudConfigurationStore.shared.configuration(for: drive) != nil else {
            presentMissingConfiguration(for: drive)
            return
        }
        
        let connector = connector(for: drive)

        if drive == .drive115 {
            let vc = Drive115QRCodeViewController(connector: connector as! Drive115Connector)
            vc.completionHandler = { (accessToken: Drive115Connector.AccessTokenPayload) in
                self.dismiss(animated: true) {
                    let credential = URLCredential(user: "user", password: accessToken.accessToken, persistence: .permanent)
                    let provider = self.provider(for: drive, credential: credential)
                    let vc = DriveBrowserViewController(provider: provider, directory: provider.rootItem)
                    self.navigationController?.pushViewController(vc, animated: true)
                }
            }
        } else {
            connector.connect(viewController: self) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let token):
                    
                    // fetch current user info to save account
                    let credential = URLCredential(user: "user", password: token.credential.oauthToken, persistence: .permanent)
                    let provider = self.provider(for: drive, credential: credential)
                    if let aliyun = provider as? AliyunDriveServiceProvider {
                        aliyun.getDriveInfo(completion: { driveInfoResult in
                            switch driveInfoResult {
                            case .success(let info):
                                aliyun.driveId = info.defaultDriveId
                                provider.getCurrentUserInfo { [weak self] userResult in
                                    guard let self = self else { return }
                                    switch userResult {
                                    case .success(let user):
                                        let account = CloudAccount(type: drive,
                                                                   username: user.username,
                                                                   oauthToken: token.credential.oauthToken)
                                        account.refreshToken = token.credential.oauthRefreshToken
                                        CloudAccountManager.shared.upsert(account)
                                        
                                        self.applyInitialSnapshot()
                                    case .failure(let error):
                                        print(error)
                                    }
                                    let vc = DriveBrowserViewController(provider: provider, directory: provider.rootItem)
                                    self.navigationController?.pushViewController(vc, animated: true)
                                }
                            case .failure(let error):
                                print(error)
                            }
                        })
                    } else {
                        provider.getCurrentUserInfo { [weak self] userResult in
                            guard let self = self else { return }
                            switch userResult {
                            case .success(let user):
                                let account = CloudAccount(type: drive,
                                                           username: user.username,
                                                           oauthToken: token.credential.oauthToken)
                                account.refreshToken = token.credential.oauthRefreshToken
                                CloudAccountManager.shared.upsert(account)
                                
                                self.applyInitialSnapshot()
                            case .failure(let error):
                                print(error)
                            }
                            let vc = DriveBrowserViewController(provider: provider, directory: provider.rootItem)
                            self.navigationController?.pushViewController(vc, animated: true)
                        }
                    }
                case .failure(let error):
                    self.presentError(error)
                }
            }
        }
        self.connector = connector
    }
    
    private func connector(for drive: CloudDriveType) -> CloudServiceConnector {
        let connector: CloudServiceConnector
        switch drive {
        case .rclone:
            let rclone = CloudConfigurationStore.shared.draft(for: .rclone)
            connector = RcloneConnector(appId: rclone.appId, appSecret: rclone.appSecret, callbackUrl: rclone.redirectUrl)
        case .aliyunDrive:
            let aliyun = CloudConfigurationStore.shared.draft(for: .aliyunDrive)
            connector = AliyunDriveConnector(appId: aliyun.appId, appSecret: aliyun.appSecret, callbackUrl: aliyun.redirectUrl)
            connector.customURLHandler = CustomOAuthWebViewController(callbackUrl: aliyun.redirectUrl)
        case .baiduPan:
            let baidu = CloudConfigurationStore.shared.draft(for: .baiduPan)
            connector = BaiduPanConnector(appId: baidu.appId, appSecret: baidu.appSecret, callbackUrl: baidu.redirectUrl)
        case .box:
            let box = CloudConfigurationStore.shared.draft(for: .box)
            connector = BoxConnector(appId: box.appId, appSecret: box.appSecret, callbackUrl: box.redirectUrl)
        case .dropbox:
            let dropbox = CloudConfigurationStore.shared.draft(for: .dropbox)
            connector = DropboxConnector(appId: dropbox.appId, appSecret: dropbox.appSecret, callbackUrl: dropbox.redirectUrl)
        case .googleDrive:
            let googledrive = CloudConfigurationStore.shared.draft(for: .googleDrive)
            connector = GoogleDriveConnector(appId: googledrive.appId, appSecret: googledrive.appSecret, callbackUrl: googledrive.redirectUrl)
        case .oneDrive:
            let onedrive = CloudConfigurationStore.shared.draft(for: .oneDrive)
            connector = OneDriveConnector(appId: onedrive.appId, appSecret: onedrive.appSecret, callbackUrl: onedrive.redirectUrl)
        case .pCloud:
            let pcloud = CloudConfigurationStore.shared.draft(for: .pCloud)
            connector = PCloudConnector(appId: pcloud.appId, appSecret: pcloud.appSecret, callbackUrl: pcloud.redirectUrl)
        case .drive115:
            let drive115 = CloudConfigurationStore.shared.draft(for: .drive115)
            connector = Drive115Connector(appId: drive115.appId, appSecret: drive115.appSecret, callbackUrl: drive115.redirectUrl)
        case .drive123:
            let drive123 = CloudConfigurationStore.shared.draft(for: .drive123)
            connector = Drive123Connector(appId: drive123.appId, appSecret: drive123.appSecret, callbackUrl: drive123.redirectUrl)
        }
        return connector
    }
    
    private func provider(for driveType: CloudDriveType, credential: URLCredential, endpoint: String? = nil) -> CloudServiceProvider {
        let provider: CloudServiceProvider
        switch driveType {
        case .rclone:
            let urlString = endpoint
                ?? CloudConfiguration.rclone?.redirectUrl
                ?? CloudConfiguration.defaultRcloneURL
            let apiURL = URL(string: urlString) ?? URL(string: CloudConfiguration.defaultRcloneURL)!
            provider = RcloneServiceProvider(credential: credential, apiURL: apiURL)
        case .aliyunDrive:
            provider = AliyunDriveServiceProvider(credential: credential)
        case .baiduPan:
            provider = BaiduPanServiceProvider(credential: credential)
        case .box:
            provider = BoxServiceProvider(credential: credential)
        case .dropbox:
            provider = DropboxServiceProvider(credential: credential)
        case .googleDrive:
            provider = GoogleDriveServiceProvider(credential: credential)
        case .oneDrive:
            provider = OneDriveServiceProvider(credential: credential)
        case .pCloud:
            provider = PCloudServiceProvider(credential: credential)
        case .drive115:
            provider = Drive115ServiceProvider(credential: credential)
        case .drive123:
            provider = Drive123ServiceProvider(credential: credential)
        }
        return provider
    }
    
    private func connectRclone() {
        let draft = CloudConfigurationStore.shared.draft(for: .rclone)
        guard draft.isConfigured(for: .rclone), let apiURL = URL(string: draft.redirectUrl) else {
            presentMissingConfiguration(for: .rclone)
            return
        }
        let credential = URLCredential(user: draft.appId, password: draft.appSecret, persistence: .permanent)
        let provider = RcloneServiceProvider(credential: credential, apiURL: apiURL)
        provider.getCurrentUserInfo { [weak self] userResult in
            guard let self = self else { return }
            switch userResult {
            case .success(let user):
                let account = CloudAccount(type: .rclone,
                                           username: draft.appId.isEmpty ? user.username : draft.appId,
                                           oauthToken: draft.appSecret,
                                           endpoint: draft.redirectUrl)
                CloudAccountManager.shared.upsert(account)
                self.applyInitialSnapshot()
                let vc = DriveBrowserViewController(provider: provider, directory: provider.rootItem)
                self.navigationController?.pushViewController(vc, animated: true)
            case .failure(let error):
                self.presentError(error, title: "Could not reach rclone")
            }
        }
    }
    
    private func presentMissingConfiguration(for drive: CloudDriveType) {
        let alert = UIAlertController(
            title: "Configure \(drive.title)",
            message: drive == .rclone
                ? "Add the rclone Remote Control URL (and optional username/password) so this browser can list your remotes."
                : "Add the OAuth app id, secret, and redirect URL for \(drive.title).",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Configure", style: .default, handler: { [weak self] _ in
            let editor = CloudProviderConfigViewController(drive: drive)
            self?.navigationController?.pushViewController(editor, animated: true)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func presentError(_ error: Error, title: String = "Error") {
        let alert = UIAlertController(title: title, message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func connect(_ account: CloudAccount) {
        if account.driveType == .rclone {
            connectSavedRclone(account)
            return
        }
        let connector = connector(for: account.driveType)
        if let refreshToken = account.refreshToken, !refreshToken.isEmpty {
            // For BaiduPan, we only refresh access token when it expires
            if account.driveType == .baiduPan {
                let credential = URLCredential(user: account.username,
                                               password: account.oauthToken,
                                               persistence: .permanent)
                let provider = provider(for: account.driveType, credential: credential, endpoint: account.endpoint)
                provider.refreshAccessTokenHandler = { [weak self] callback in
                    guard let self = self else { return }
                    self.refreshAccessToken(with: refreshToken, connector: connector, account: account) { result in
                        callback?(result)
                    }
                }
                let vc = DriveBrowserViewController(provider: provider, directory: provider.rootItem)
                self.navigationController?.pushViewController(vc, animated: true)
            } else {
                connector.renewToken(with: refreshToken) { result in
                    switch result {
                    case .success(let token):
                        
                        // update oauth token and refresh token of existing account
                        account.oauthToken = token.credential.oauthToken
                        if !token.credential.oauthRefreshToken.isEmpty {
                            account.refreshToken = token.credential.oauthRefreshToken
                        }
                        CloudAccountManager.shared.upsert(account)
                        
                        // create CloudServiceProvider with new oauth token
                        let credential = URLCredential(user: account.username,
                                                       password: token.credential.oauthToken,
                                                       persistence: .permanent)
                        let provider = self.provider(for: account.driveType, credential: credential, endpoint: account.endpoint)
                        
                        let vc = DriveBrowserViewController(provider: provider, directory: provider.rootItem)
                        self.navigationController?.pushViewController(vc, animated: true)
                    case .failure(let error):
                        self.presentError(error)
                    }
                }
            }
        } else {
            // For pCloud which do not contains refresh token and its oauth is valid for long time
            // we just use cached oauth token to create CloudServiceProvider
            let credential = URLCredential(user: account.username,
                                           password: account.oauthToken,
                                           persistence: .permanent)
            let provider = provider(for: account.driveType, credential: credential, endpoint: account.endpoint)
            let vc = DriveBrowserViewController(provider: provider, directory: provider.rootItem)
            self.navigationController?.pushViewController(vc, animated: true)
        }
        self.connector = connector
    }
    
    private func connectSavedRclone(_ account: CloudAccount) {
        let config = CloudConfigurationStore.shared.draft(for: .rclone)
        let user = config.appId.isEmpty ? account.username : config.appId
        let password = config.appSecret.isEmpty ? account.oauthToken : config.appSecret
        let endpoint = account.endpoint ?? config.redirectUrl
        guard let apiURL = URL(string: endpoint), !endpoint.isEmpty else {
            presentMissingConfiguration(for: .rclone)
            return
        }
        let credential = URLCredential(user: user, password: password, persistence: .permanent)
        let provider = RcloneServiceProvider(credential: credential, apiURL: apiURL)
        let vc = DriveBrowserViewController(provider: provider, directory: provider.rootItem)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func refreshAccessToken(with refreshToken: String, connector: CloudServiceConnector, account: CloudAccount, completionHandler: @escaping (Result<URLCredential, Error>) -> Void) {
        connector.renewToken(with: refreshToken) { result in
            switch result {
            case .success(let token):
                // update oauth token and refresh token of existing account
                account.oauthToken = token.credential.oauthToken
                if !token.credential.oauthRefreshToken.isEmpty {
                    account.refreshToken = token.credential.oauthRefreshToken
                }
                CloudAccountManager.shared.upsert(account)
                let credential = URLCredential(user: account.username,
                                               password: token.credential.oauthToken,
                                               persistence: .permanent)
                completionHandler(.success(credential))
            case .failure(let error):
                completionHandler(.failure(error))
            }
        }
    }
}

// MARK: - Setup
extension ViewController {
    
    private func setupCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.delegate = self
        collectionView.backgroundColor = .systemBackground
        view.addSubview(collectionView)
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        return UICollectionViewCompositionalLayout.list(using: configuration)
    }
    
    private func setupDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { (cell, indexPath, item) in
            var content = cell.defaultContentConfiguration()
            switch item {
            case .cached(let account):
                content.image = account.driveType.image
                content.text = account.username
            case .provider(let driveItem):
                content.image = driveItem.image
                content.text = driveItem.title
            }
            cell.contentConfiguration = content
        }
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView, cellProvider: { collectionView, indexPath, item in
            return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        })
    }
    
    private func applyInitialSnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.main])
        snapshot.appendItems(CloudDriveType.allCases.map { Item.provider($0) }, toSection: .main)
        
        let accounts = CloudAccountManager.shared.accounts
        if !accounts.isEmpty {
            snapshot.appendSections([.saved])
            snapshot.appendItems(accounts.map { Item.cached($0) }, toSection: .saved)
        }
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: - UICollectionViewDelegate
extension ViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        switch item {
        case .provider(let driveType):
            connect(driveType)
        case .cached(let account):
            connect(account)
        }
    }
}
