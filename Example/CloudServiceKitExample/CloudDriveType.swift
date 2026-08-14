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
            return "rclonegui is configured. Tap Find live rclone GUI to probe rclonegui.shannonjlove.cloud, files.shannonjlove.cloud, rclone.shannonjlove.cloud, rclone-mcp, then Oracle Tailscale :5572. The first host that answers is saved. Deploy the stack in deploy/rclonegui if none answer.\n\nOr start locally:\nrclone rcd --rc-web-gui --rc-addr :5572 --rc-user USER --rc-pass PASS"
        default:
            return "Create an OAuth application in the provider console. Set the redirect URL to \(CloudConfiguration.defaultOAuthCallbackURL) (already registered in Info.plist) unless the provider requires its own callback."
        }
    }
}
