//
//  CloudConfiguration.swift
//  CloudServiceKitExample
//
//  Created by alexiscn on 2021/9/28.
//

import Foundation
import KeychainAccess

struct CloudConfiguration: Codable, Equatable {
    
    var appId: String
    
    var appSecret: String
    
    var redirectUrl: String
    
    var isEmpty: Bool {
        return appId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && appSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && redirectUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    func isConfigured(for drive: CloudDriveType) -> Bool {
        let redirect = redirectUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        switch drive {
        case .rclone:
            return !redirect.isEmpty
        case .drive115:
            return !appId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return !appId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !appSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !redirect.isEmpty
        }
    }
}

extension CloudConfiguration {
    
    static let defaultOAuthCallbackURL = "oauth-swift://oauth-callback"
    
    /// Canonical rclone GUI hostname. Failover URLs are in `rcloneCandidateURLs`.
    static let defaultRcloneURL = "https://rclonegui.shannonjlove.cloud"
    
    /// LoveCloud RC / Web GUI hosts, then Tailscale / local. First one that answers wins.
    static let rcloneFailoverURLs = [
        "https://rclonegui.shannonjlove.cloud",
        "https://files.shannonjlove.cloud",
        "https://rclone.shannonjlove.cloud",
        "https://rclone-mcp.shannonjlove.cloud",
        "http://100.67.229.94:5572",
        "http://10.89.1.62:5572",
        "http://127.0.0.1:5572"
    ]
    
    static func rcloneCandidateURLs(preferred: String?) -> [URL] {
        var seen = Set<String>()
        var ordered: [String] = []
        let extras = [preferred].compactMap { $0 } + rcloneFailoverURLs
        for raw in extras {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            if seen.insert(key).inserted {
                ordered.append(trimmed)
            }
        }
        return ordered.compactMap { URL(string: $0) }
    }
    
    static var aliyun: CloudConfiguration? {
        CloudConfigurationStore.shared.configuration(for: .aliyunDrive)
    }
    
    static var baidu: CloudConfiguration? {
        CloudConfigurationStore.shared.configuration(for: .baiduPan)
    }
    
    static var box: CloudConfiguration? {
        CloudConfigurationStore.shared.configuration(for: .box)
    }
    
    static var dropbox: CloudConfiguration? {
        CloudConfigurationStore.shared.configuration(for: .dropbox)
    }
    
    static var googleDrive: CloudConfiguration? {
        CloudConfigurationStore.shared.configuration(for: .googleDrive)
    }
    
    static var oneDrive: CloudConfiguration? {
        CloudConfigurationStore.shared.configuration(for: .oneDrive)
    }
    
    static var pCloud: CloudConfiguration? {
        CloudConfigurationStore.shared.configuration(for: .pCloud)
    }
    
    static var drive115: CloudConfiguration? {
        CloudConfigurationStore.shared.configuration(for: .drive115)
    }
    
    static var drive123: CloudConfiguration? {
        CloudConfigurationStore.shared.configuration(for: .drive123)
    }
    
    static var rclone: CloudConfiguration? {
        CloudConfigurationStore.shared.configuration(for: .rclone)
    }
}

/// Loads OAuth / rclone credentials from Keychain, then a bundled plist, then built-in defaults.
final class CloudConfigurationStore {
    
    static let shared = CloudConfigurationStore()
    
    static let didChangeNotification = Notification.Name("CloudConfigurationStoreDidChange")
    
    private let keychain = Keychain(service: "me.shuifeng.CloudServiceKit.CloudConfiguration")
    
    private var memory: [CloudDriveType: CloudConfiguration] = [:]
    
    private init() {
        memory = loadFromPlist().merging(loadFromKeychain()) { _, keychain in keychain }
        if memory[.rclone] == nil {
            memory[.rclone] = CloudConfiguration(appId: "", appSecret: "", redirectUrl: CloudConfiguration.defaultRcloneURL)
        }
    }
    
    func configuration(for drive: CloudDriveType) -> CloudConfiguration? {
        guard let config = memory[drive], config.isConfigured(for: drive) else {
            return nil
        }
        return config
    }
    
    func draft(for drive: CloudDriveType) -> CloudConfiguration {
        if let existing = memory[drive] {
            return existing
        }
        switch drive {
        case .rclone:
            return CloudConfiguration(appId: "", appSecret: "", redirectUrl: CloudConfiguration.defaultRcloneURL)
        default:
            return CloudConfiguration(appId: "", appSecret: "", redirectUrl: CloudConfiguration.defaultOAuthCallbackURL)
        }
    }
    
    func save(_ configuration: CloudConfiguration, for drive: CloudDriveType) {
        memory[drive] = configuration
        persistToKeychain()
        NotificationCenter.default.post(name: CloudConfigurationStore.didChangeNotification, object: drive)
    }
    
    func remove(_ drive: CloudDriveType) {
        memory.removeValue(forKey: drive)
        persistToKeychain()
        NotificationCenter.default.post(name: CloudConfigurationStore.didChangeNotification, object: drive)
    }
    
    private func persistToKeychain() {
        let payload = Dictionary(uniqueKeysWithValues: memory.map { ($0.key.rawValue, $0.value) })
        do {
            let data = try JSONEncoder().encode(payload)
            try keychain.set(data, key: "provider-configurations")
        } catch {
            print(error)
        }
    }
    
    private func loadFromKeychain() -> [CloudDriveType: CloudConfiguration] {
        guard let data = try? keychain.getData("provider-configurations") else {
            return [:]
        }
        guard let payload = try? JSONDecoder().decode([String: CloudConfiguration].self, from: data) else {
            return [:]
        }
        var result: [CloudDriveType: CloudConfiguration] = [:]
        for (key, value) in payload {
            if let drive = CloudDriveType(rawValue: key) {
                result[drive] = value
            }
        }
        return result
    }
    
    private func loadFromPlist() -> [CloudDriveType: CloudConfiguration] {
        let urls = [
            Bundle.main.url(forResource: "CloudConfiguration", withExtension: "plist"),
            Bundle.main.url(forResource: "CloudConfiguration.example", withExtension: "plist")
        ].compactMap { $0 }
        guard let url = urls.first,
              let raw = NSDictionary(contentsOf: url) as? [String: Any] else {
            return [:]
        }
        var result: [CloudDriveType: CloudConfiguration] = [:]
        for drive in CloudDriveType.allCases {
            guard let entry = raw[drive.rawValue] as? [String: Any] else {
                continue
            }
            let config = CloudConfiguration(
                appId: (entry["appId"] as? String) ?? "",
                appSecret: (entry["appSecret"] as? String) ?? "",
                redirectUrl: (entry["redirectUrl"] as? String) ?? ""
            )
            if !config.isEmpty {
                result[drive] = config
            }
        }
        return result
    }
}
