//
//  CloudDriveType.swift
//  CloudServiceKitExample
//
//  Created by alexiscn on 2021/9/18.
//

import Foundation
import UIKit

enum CloudDriveType: String, Codable, CaseIterable, Hashable {
    case rclone
    case aliyunDrive
    case baiduPan
    case box
    case dropbox
    case googleDrive
    case oneDrive
    case pCloud
    case drive115
    case drive123
    
    var title: String {
        switch self {
        case .rclone: return "rclone"
        case .aliyunDrive: return "Aliyun Drive"
        case .baiduPan: return "Baidu Pan"
        case .box: return "Box"
        case .dropbox: return "Dropbox"
        case .googleDrive: return "Google Drive"
        case .oneDrive: return "OneDrive"
        case .pCloud: return "pCloud"
        case .drive115: return "115"
        case .drive123: return "123Pan"
        }
    }
    
    var image: UIImage? {
        switch self {
        case .rclone: return UIImage(systemName: "externaldrive.badge.icloud")
        case .aliyunDrive: return UIImage(named: "aliyundrive")
        case .baiduPan: return UIImage(named: "baidupan")
        case .box: return UIImage(named: "box")
        case .dropbox: return UIImage(named: "dropbox")
        case .googleDrive: return UIImage(named: "googledrive")
        case .oneDrive: return UIImage(named: "onedrive")
        case .pCloud: return UIImage(named: "pcloud")
        case .drive115: return UIImage(named: "115")
        case .drive123: return UIImage(named: "123")
        }
    }
    
    var appIdLabel: String {
        switch self {
        case .rclone: return "RC username (--rc-user)"
        default: return "App ID / Client ID"
        }
    }
    
    var appSecretLabel: String {
        switch self {
        case .rclone: return "RC password (--rc-pass)"
        default: return "App secret / Client secret"
        }
    }
    
    var redirectLabel: String {
        switch self {
        case .rclone: return "Remote Control URL"
        default: return "Redirect URL"
        }
    }
    
    var appIdPlaceholder: String {
        switch self {
        case .rclone: return "optional if --rc-no-auth"
        default: return "client id"
        }
    }
    
    var appSecretPlaceholder: String {
        switch self {
        case .rclone: return "optional if --rc-no-auth"
        default: return "client secret"
        }
    }
    
    var redirectPlaceholder: String {
        switch self {
        case .rclone: return CloudConfiguration.defaultRcloneURL
        default: return CloudConfiguration.defaultOAuthCallbackURL
        }
    }
    
    var configurationHelp: String {
        switch self {
        case .rclone:
            return "Start rclone with a web GUI / RC server, then paste that URL here. Example:\n\nrclone rcd --rc-web-gui --rc-addr :5572 --rc-user USER --rc-pass PASS\n\nOn LoveCloud the RC endpoint is https://rclone-mcp.shannonjlove.cloud (and the GUI is files.shannonjlove.cloud). Username and password can be left blank when the server uses --rc-no-auth."
        default:
            return "Create an OAuth application in the provider console. Set the redirect URL to \(CloudConfiguration.defaultOAuthCallbackURL) (already registered in Info.plist) unless the provider requires its own callback."
        }
    }
}
