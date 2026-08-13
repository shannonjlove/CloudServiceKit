//
//  RcloneServiceProvider.swift
//  CloudServiceKit
//
//  Talks to an rclone Remote Control server (`rclone rcd` / rclone Web GUI)
//  so the Drive Browser can list and manage every configured remote.
//  See https://rclone.org/rc/
//

import Foundation

/// Splits an rclone path such as `gdrive:Documents/Work` into RC `fs` + `remote`.
struct RclonePath {
    let fs: String
    let remote: String

    var joined: String {
        remote.isEmpty ? fs : fs + remote
    }

    func child(_ name: String) -> String {
        if remote.isEmpty {
            return fs + name
        }
        return fs + remote + "/" + name
    }

    /// Returns `nil` for the RC root (the list of remotes).
    static func parse(_ path: String) -> RclonePath? {
        var trimmed = path
        if trimmed.hasPrefix("/") {
            trimmed.removeFirst()
        }
        if trimmed.isEmpty {
            return nil
        }
        if let colon = trimmed.firstIndex(of: ":") {
            let name = String(trimmed[..<colon])
            let rest = String(trimmed[trimmed.index(after: colon)...])
            return RclonePath(fs: name + ":", remote: rest)
        }
        return RclonePath(fs: trimmed + ":", remote: "")
    }
}

/// Cloud provider backed by [rclone Remote Control](https://rclone.org/rc/).
///
/// Point `apiURL` at an `rclone rcd` endpoint (for example
/// `http://127.0.0.1:5572` or `https://rclone-mcp.shannonjlove.cloud`).
/// `credential.user` / `credential.password` are the RC basic-auth username
/// and password (`--rc-user` / `--rc-pass`). Leave them empty when the RC
/// server is started with `--rc-no-auth`.
public class RcloneServiceProvider: CloudServiceProvider {

    public var delegate: CloudServiceProviderDelegate?

    public var name: String { return "rclone" }

    public var rootItem: CloudItem { return CloudItem(id: "rclone", name: name, path: "/") }

    public var credential: URLCredential?

    /// Base URL of the rclone RC / Web GUI server.
    public var apiURL = URL(string: "http://127.0.0.1:5572")!

    public var refreshAccessTokenHandler: CloudRefreshAccessTokenHandler?

    required public init(credential: URLCredential?) {
        self.credential = credential
    }

    public init(credential: URLCredential?, apiURL: URL) {
        self.credential = credential
        self.apiURL = apiURL
    }

    /// Tries each RC URL in order and returns the first provider that answers `core/version`.
    public static func connectToFirstAvailable(urls: [URL],
                                               credential: URLCredential?,
                                               completion: @escaping (Result<RcloneServiceProvider, Error>) -> Void) {
        tryNextAvailable(urls: urls, credential: credential, lastError: nil, completion: completion)
    }

    private static func tryNextAvailable(urls: [URL],
                                         credential: URLCredential?,
                                         lastError: Error?,
                                         completion: @escaping (Result<RcloneServiceProvider, Error>) -> Void) {
        guard let url = urls.first else {
            let error = lastError ?? CloudServiceError.serviceError(503, "No rclone Remote Control endpoint responded")
            completion(.failure(error))
            return
        }
        let provider = RcloneServiceProvider(credential: credential, apiURL: url)
        provider.getCurrentUserInfo { result in
            switch result {
            case .success:
                completion(.success(provider))
            case .failure(let error):
                tryNextAvailable(urls: Array(urls.dropFirst()),
                                 credential: credential,
                                 lastError: error,
                                 completion: completion)
            }
        }
    }

    public func attributesOfItem(_ item: CloudItem, completion: @escaping (Result<CloudItem, Error>) -> Void) {
        guard let path = RclonePath.parse(item.path) else {
            completion(.success(rootItem))
            return
        }
        rc("operations/stat", json: ["fs": path.fs, "remote": path.remote]) { result in
            switch result {
            case .success(let response):
                if let json = response.json as? [String: Any],
                   let itemJSON = json["item"] as? [String: Any],
                   let parsed = RcloneServiceProvider.cloudItemFromJSON(itemJSON, fs: path.fs) {
                    completion(.success(parsed))
                } else if let json = response.json as? [String: Any],
                          let parsed = RcloneServiceProvider.cloudItemFromJSON(json, fs: path.fs) {
                    completion(.success(parsed))
                } else {
                    completion(.failure(CloudServiceError.responseDecodeError(response)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    public func contentsOfDirectory(_ directory: CloudItem, completion: @escaping (Result<[CloudItem], Error>) -> Void) {
        guard let path = RclonePath.parse(directory.path) else {
            listRemotes(completion: completion)
            return
        }
        var json: [String: Any] = [
            "fs": path.fs,
            "remote": path.remote
        ]
        json["opt"] = ["recurse": false]
        rc("operations/list", json: json) { result in
            switch result {
            case .success(let response):
                if let object = response.json as? [String: Any],
                   let list = object["list"] as? [[String: Any]] {
                    let items = list.compactMap { RcloneServiceProvider.cloudItemFromJSON($0, fs: path.fs) }
                    completion(.success(items))
                } else {
                    completion(.failure(CloudServiceError.responseDecodeError(response)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    public func copyItem(_ item: CloudItem, to directory: CloudItem, completion: @escaping CloudCompletionHandler) {
        guard let src = RclonePath.parse(item.path),
              let dstDir = RclonePath.parse(directory.path) else {
            completion(.init(response: nil, result: .failure(CloudServiceError.unsupported)))
            return
        }
        let dstRemote = dstDir.remote.isEmpty ? item.name : dstDir.remote + "/" + item.name
        if item.isDirectory {
            let srcFs = src.remote.isEmpty ? src.fs : src.fs + src.remote
            let dstFs = dstDir.fs + dstRemote
            rc("sync/copy", json: ["srcFs": srcFs, "dstFs": dstFs]) { result in
                self.finish(result, completion: completion)
            }
        } else {
            let json: [String: Any] = [
                "srcFs": src.fs,
                "srcRemote": src.remote,
                "dstFs": dstDir.fs,
                "dstRemote": dstRemote
            ]
            rc("operations/copyfile", json: json) { result in
                self.finish(result, completion: completion)
            }
        }
    }

    public func createFolder(_ folderName: String, at directory: CloudItem, completion: @escaping CloudCompletionHandler) {
        guard let path = RclonePath.parse(directory.path) else {
            completion(.init(response: nil, result: .failure(CloudServiceError.unsupported)))
            return
        }
        let remote = path.remote.isEmpty ? folderName : path.remote + "/" + folderName
        rc("operations/mkdir", json: ["fs": path.fs, "remote": remote]) { result in
            self.finish(result, completion: completion)
        }
    }

    public func getCloudSpaceInformation(completion: @escaping (Result<CloudSpaceInformation, Error>) -> Void) {
        listRemotes { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let remotes):
                self.spaceInformation(for: remotes, completion: completion)
            }
        }
    }

    public func getCurrentUserInfo(completion: @escaping (Result<CloudUser, Error>) -> Void) {
        rc("core/version") { [weak self] result in
            switch result {
            case .success(let response):
                let json = (response.json as? [String: Any]) ?? [:]
                let version = json["version"] as? String
                let user = self?.credential?.user
                let username: String
                if let user = user, !user.isEmpty {
                    username = user
                } else if let version = version, !version.isEmpty {
                    username = "rclone \(version)"
                } else {
                    username = "rclone"
                }
                completion(.success(CloudUser(username: username, json: json)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    public func moveItem(_ item: CloudItem, to directory: CloudItem, completion: @escaping CloudCompletionHandler) {
        guard let src = RclonePath.parse(item.path),
              let dstDir = RclonePath.parse(directory.path) else {
            completion(.init(response: nil, result: .failure(CloudServiceError.unsupported)))
            return
        }
        let dstRemote = dstDir.remote.isEmpty ? item.name : dstDir.remote + "/" + item.name
        if item.isDirectory {
            let srcFs = src.remote.isEmpty ? src.fs : src.fs + src.remote
            let dstFs = dstDir.fs + dstRemote
            rc("sync/move", json: ["srcFs": srcFs, "dstFs": dstFs]) { result in
                self.finish(result, completion: completion)
            }
        } else {
            let json: [String: Any] = [
                "srcFs": src.fs,
                "srcRemote": src.remote,
                "dstFs": dstDir.fs,
                "dstRemote": dstRemote
            ]
            rc("operations/movefile", json: json) { result in
                self.finish(result, completion: completion)
            }
        }
    }

    public func removeItem(_ item: CloudItem, completion: @escaping CloudCompletionHandler) {
        guard let path = RclonePath.parse(item.path) else {
            completion(.init(response: nil, result: .failure(CloudServiceError.unsupported)))
            return
        }
        let command = item.isDirectory ? "operations/purge" : "operations/deletefile"
        rc(command, json: ["fs": path.fs, "remote": path.remote]) { result in
            self.finish(result, completion: completion)
        }
    }

    public func renameItem(_ item: CloudItem, newName: String, completion: @escaping CloudCompletionHandler) {
        guard let src = RclonePath.parse(item.path) else {
            completion(.init(response: nil, result: .failure(CloudServiceError.unsupported)))
            return
        }
        let parent = (src.remote as NSString).deletingLastPathComponent
        let dstRemote: String
        if parent.isEmpty || parent == "." {
            dstRemote = newName
        } else {
            dstRemote = parent + "/" + newName
        }
        if item.isDirectory {
            let srcFs = src.remote.isEmpty ? src.fs : src.fs + src.remote
            let dstFs = src.fs + dstRemote
            rc("sync/move", json: ["srcFs": srcFs, "dstFs": dstFs]) { result in
                self.finish(result, completion: completion)
            }
        } else {
            let json: [String: Any] = [
                "srcFs": src.fs,
                "srcRemote": src.remote,
                "dstFs": src.fs,
                "dstRemote": dstRemote
            ]
            rc("operations/movefile", json: json) { result in
                self.finish(result, completion: completion)
            }
        }
    }

    public func searchFiles(keyword: String, completion: @escaping (Result<[CloudItem], Error>) -> Void) {
        listRemotes { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let remotes):
                self.search(keyword: keyword, in: remotes, completion: completion)
            }
        }
    }

    public func uploadData(_ data: Data, filename: String, to directory: CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        guard let path = RclonePath.parse(directory.path) else {
            completion(.init(response: nil, result: .failure(CloudServiceError.unsupported)))
            return
        }
        let reportProgress = Progress(totalUnitCount: Int64(data.count))
        let files = [filename: HTTPFile.data(filename, data, nil)]
        let payload: [String: Any] = ["fs": path.fs, "remote": path.remote]
        rc("operations/uploadfile", data: payload, files: files, progressHandler: { httpProgress in
            reportProgress.completedUnitCount = Int64(Float(data.count) * httpProgress.percent)
            progressHandler(reportProgress)
        }) { result in
            self.finish(result, completion: completion)
        }
    }

    public func uploadFile(_ fileURL: URL, to directory: CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudCompletionHandler) {
        guard FileManager.default.fileExists(atPath: fileURL.path), let totalSize = fileSize(of: fileURL) else {
            completion(.init(response: nil, result: .failure(CloudServiceError.uploadFileNotExist)))
            return
        }
        guard let path = RclonePath.parse(directory.path) else {
            completion(.init(response: nil, result: .failure(CloudServiceError.unsupported)))
            return
        }
        let filename = fileURL.lastPathComponent
        let reportProgress = Progress(totalUnitCount: totalSize)
        let files = [filename: HTTPFile.url(fileURL, nil)]
        let payload: [String: Any] = ["fs": path.fs, "remote": path.remote]
        rc("operations/uploadfile", data: payload, files: files, progressHandler: { httpProgress in
            reportProgress.completedUnitCount = Int64(Float(totalSize) * httpProgress.percent)
            progressHandler(reportProgress)
        }) { result in
            self.finish(result, completion: completion)
        }
    }
}

// MARK: - RC client
private extension RcloneServiceProvider {

    var basicAuth: (String, String)? {
        let user = credential?.user ?? ""
        let password = credential?.password ?? ""
        if user.isEmpty && password.isEmpty {
            return nil
        }
        return (user, password)
    }

    func rcURL(_ command: String) -> URL {
        var base = apiURL.absoluteString
        if base.hasSuffix("/") {
            base.removeLast()
        }
        return URL(string: base + "/" + command) ?? apiURL
    }

    func listRemotes(completion: @escaping (Result<[CloudItem], Error>) -> Void) {
        rc("config/listremotes") { result in
            switch result {
            case .success(let response):
                if let object = response.json as? [String: Any],
                   let remotes = object["remotes"] as? [String] {
                    let items = remotes.map { name -> CloudItem in
                        let fs = name.hasSuffix(":") ? name : name + ":"
                        return CloudItem(id: fs, name: name, path: fs, isDirectory: true)
                    }
                    completion(.success(items))
                } else {
                    completion(.failure(CloudServiceError.responseDecodeError(response)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func spaceInformation(for remotes: [CloudItem], completion: @escaping (Result<CloudSpaceInformation, Error>) -> Void) {
        if remotes.isEmpty {
            completion(.success(CloudSpaceInformation(totalSpace: 0, availableSpace: 0, json: [:])))
            return
        }
        var remaining = remotes.count
        var total: Int64 = 0
        var available: Int64 = 0
        var merged: [String: Any] = [:]
        var firstError: Error?
        let lock = NSLock()

        for remote in remotes {
            guard let path = RclonePath.parse(remote.path) else {
                lock.lock()
                remaining -= 1
                let done = remaining == 0
                lock.unlock()
                if done {
                    finishSpace(total: total, available: available, json: merged, error: firstError, completion: completion)
                }
                continue
            }
            rc("operations/about", json: ["fs": path.fs]) { result in
                lock.lock()
                switch result {
                case .success(let response):
                    if let json = response.json as? [String: Any] {
                        merged[remote.name] = json
                        if let used = int64Value(json["used"]), let free = int64Value(json["free"]) {
                            available += free
                            if let remoteTotal = int64Value(json["total"]) {
                                total += remoteTotal
                            } else {
                                total += used + free
                            }
                        } else if let remoteTotal = int64Value(json["total"]), let used = int64Value(json["used"]) {
                            total += remoteTotal
                            available += max(remoteTotal - used, 0)
                        }
                    }
                case .failure(let error):
                    if firstError == nil {
                        firstError = error
                    }
                }
                remaining -= 1
                let done = remaining == 0
                let snapshotTotal = total
                let snapshotAvailable = available
                let snapshotJSON = merged
                let snapshotError = firstError
                lock.unlock()
                if done {
                    self.finishSpace(total: snapshotTotal, available: snapshotAvailable, json: snapshotJSON, error: snapshotError, completion: completion)
                }
            }
        }
    }

    func finishSpace(total: Int64, available: Int64, json: [String: Any], error: Error?, completion: @escaping (Result<CloudSpaceInformation, Error>) -> Void) {
        if total == 0 && available == 0, let error = error, json.isEmpty {
            completion(.failure(error))
            return
        }
        completion(.success(CloudSpaceInformation(totalSpace: total, availableSpace: available, json: json)))
    }

    func search(keyword: String, in remotes: [CloudItem], completion: @escaping (Result<[CloudItem], Error>) -> Void) {
        if remotes.isEmpty {
            completion(.success([]))
            return
        }
        let needle = keyword.lowercased()
        var remaining = remotes.count
        var matches: [CloudItem] = []
        var firstError: Error?
        let lock = NSLock()

        for remote in remotes {
            guard let path = RclonePath.parse(remote.path) else {
                lock.lock()
                remaining -= 1
                let done = remaining == 0
                lock.unlock()
                if done {
                    completion(.success(matches))
                }
                continue
            }
            var json: [String: Any] = ["fs": path.fs, "remote": ""]
            json["opt"] = ["recurse": true]
            rc("operations/list", json: json) { result in
                lock.lock()
                switch result {
                case .success(let response):
                    if let object = response.json as? [String: Any],
                       let list = object["list"] as? [[String: Any]] {
                        let items = list.compactMap { RcloneServiceProvider.cloudItemFromJSON($0, fs: path.fs) }
                            .filter { $0.name.lowercased().contains(needle) }
                        matches.append(contentsOf: items)
                    }
                case .failure(let error):
                    if firstError == nil {
                        firstError = error
                    }
                }
                remaining -= 1
                let done = remaining == 0
                let snapshot = matches
                let snapshotError = firstError
                lock.unlock()
                if done {
                    if snapshot.isEmpty, let snapshotError = snapshotError {
                        completion(.failure(snapshotError))
                    } else {
                        completion(.success(snapshot))
                    }
                }
            }
        }
    }

    func finish(_ result: Result<HTTPResult, Error>, completion: CloudCompletionHandler) {
        switch result {
        case .success(let response):
            completion(.init(response: response, result: .success(response)))
        case .failure(let error):
            completion(.init(response: nil, result: .failure(error)))
        }
    }

    func rc(_ command: String,
            json: [String: Any] = [:],
            data: [String: Any] = [:],
            files: [String: HTTPFile] = [:],
            progressHandler: ((HTTPProgress) -> Void)? = nil,
            completion: @escaping (Result<HTTPResult, Error>) -> Void) {
        let url = rcURL(command)
        let jsonBody: Any? = files.isEmpty ? json : nil
        Just.post(url,
                  data: data,
                  json: jsonBody,
                  files: files,
                  auth: basicAuth,
                  asyncProgressHandler: { progress in
            DispatchQueue.main.async {
                progressHandler?(progress)
            }
        }, asyncCompletionHandler: { response in
            DispatchQueue.main.async {
                if let error = response.error {
                    completion(.failure(error))
                    return
                }
                if let object = response.json as? [String: Any],
                   let message = object["error"] as? String,
                   !message.isEmpty {
                    let code = response.statusCode ?? 400
                    completion(.failure(CloudServiceError.serviceError(code, message)))
                    return
                }
                if let status = response.statusCode, status >= 400 {
                    completion(.failure(CloudServiceError.serviceError(status, response.text)))
                    return
                }
                completion(.success(response))
            }
        })
    }
}

private func int64Value(_ value: Any?) -> Int64? {
    if let number = value as? Int64 {
        return number
    }
    if let number = value as? Int {
        return Int64(number)
    }
    if let number = value as? Double {
        return Int64(number)
    }
    if let number = value as? NSNumber {
        return number.int64Value
    }
    return nil
}

// MARK: - CloudServiceResponseProcessing
extension RcloneServiceProvider: CloudServiceResponseProcessing {

    public static func cloudItemFromJSON(_ json: [String: Any]) -> CloudItem? {
        cloudItemFromJSON(json, fs: "")
    }

    static func cloudItemFromJSON(_ json: [String: Any], fs: String) -> CloudItem? {
        let name = (json["Name"] as? String) ?? (json["name"] as? String)
        guard let name = name else {
            return nil
        }
        let relative = (json["Path"] as? String) ?? (json["path"] as? String) ?? name
        let isDirectory = (json["IsDir"] as? Bool) ?? (json["isDir"] as? Bool) ?? false
        let path = fs + relative
        let item = CloudItem(id: path, name: name, path: path, isDirectory: isDirectory, json: json)
        if let size = int64Value(json["Size"]) ?? int64Value(json["size"]) {
            item.size = size
        }
        if let hashes = json["Hashes"] as? [String: Any] {
            item.fileHash = (hashes["SHA-1"] as? String) ?? (hashes["MD5"] as? String) ?? (hashes["SHA-256"] as? String)
        }
        if let modified = (json["ModTime"] as? String) ?? (json["modTime"] as? String) {
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            item.modificationDate = fractional.date(from: modified)
                ?? ISO8601DateFormatter().date(from: modified)
        }
        return item
    }

    public func shouldProcessResponse(_ response: HTTPResult, completion: @escaping CloudCompletionHandler) -> Bool {
        guard let json = response.json as? [String: Any],
              let message = json["error"] as? String,
              !message.isEmpty else {
            return false
        }
        let code = response.statusCode ?? 400
        completion(.init(response: response, result: .failure(CloudServiceError.serviceError(code, message))))
        return true
    }
}
