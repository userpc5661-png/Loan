import AVFoundation
import Foundation

@MainActor
@Observable
final class DownloadCenter {
    static let shared = DownloadCenter()

    private(set) var items: [DownloadItem] = []
    var backgroundCompletion: (() -> Void)?
    private var library: LibraryStore?
    private let bridge = SessionBridge()
    private var fileSession: URLSession!
    private var assetSession: AVAssetDownloadURLSession?
    private var tasks: [String: URLSessionTask] = [:]

    private init() {
        bridge.owner = self
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        fileSession = URLSession(configuration: configuration, delegate: bridge, delegateQueue: .main)
    }

    func bind(library: LibraryStore) {
        self.library = library
        items = library.downloads().map { item in
            var copy = item
            if copy.state == .downloading || copy.state == .queued {
                copy.state = .failed
                copy.errorMessage = copy.errorMessage.isEmpty ? "توقف التنزيل. أعد المحاولة." : copy.errorMessage
            }
            return copy
        }
        items.forEach { library.upsertDownload($0) }
    }

    func item(_ mediaID: String) -> DownloadItem? {
        items.first { $0.mediaID == mediaID }
    }

    func localURL(for mediaID: String) -> URL? {
        guard let item = item(mediaID), item.state == .finished else { return nil }
        if let data = item.bookmarkData {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale) {
                return url
            }
        }
        if !item.localPath.isEmpty {
            let url = URL(fileURLWithPath: item.localPath)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    func start(mediaID: String, title: String, posterAsset: String?, posterURL: String?, remote: URL) {
        if let existing = item(mediaID), existing.state == .finished || existing.state == .downloading {
            return
        }
        let isHLS = remote.absoluteString.lowercased().contains(".m3u8")
        var item = DownloadItem(
            mediaID: mediaID,
            title: title,
            posterAsset: posterAsset ?? "",
            posterURL: posterURL ?? "",
            remoteURL: remote.absoluteString,
            localPath: "",
            bookmarkData: nil,
            state: .downloading,
            progress: 0,
            errorMessage: "",
            isHLS: isHLS
        )
        upsert(item)
        if isHLS {
            let session = ensureAssetSession()
            let asset = AVURLAsset(url: remote)
            let configuration = AVAssetDownloadConfiguration(asset: asset, title: title)
            let task = session.makeAssetDownloadTask(downloadConfiguration: configuration)
            task.taskDescription = mediaID
            tasks[mediaID] = task
            task.resume()
        } else {
            let task = fileSession.downloadTask(with: remote)
            task.taskDescription = mediaID
            tasks[mediaID] = task
            task.resume()
        }
    }

    func cancel(mediaID: String) {
        tasks[mediaID]?.cancel()
        tasks[mediaID] = nil
        guard var item = item(mediaID), item.state != .finished else { return }
        item.state = .failed
        item.errorMessage = "أُلغي التنزيل."
        upsert(item)
    }

    func remove(mediaID: String) {
        tasks[mediaID]?.cancel()
        tasks[mediaID] = nil
        if let item = item(mediaID), !item.localPath.isEmpty {
            try? FileManager.default.removeItem(atPath: item.localPath)
        }
        items.removeAll { $0.mediaID == mediaID }
        library?.deleteDownload(mediaID)
    }

    fileprivate func updateProgress(mediaID: String?, value: Double) {
        guard let mediaID, var item = item(mediaID), value.isFinite else { return }
        item.progress = min(max(value, 0), 1)
        item.state = .downloading
        upsert(item, persist: item.progress > 0.98 || Int(item.progress * 20) != Int((item.progress - 0.02) * 20))
    }

    fileprivate func finishFile(mediaID: String?, path: String) {
        guard let mediaID, var item = item(mediaID) else { return }
        item.localPath = path
        item.progress = 1
        item.state = .finished
        item.errorMessage = ""
        tasks[mediaID] = nil
        upsert(item)
    }

    fileprivate func noteHLSLocation(mediaID: String?, path: String, bookmark: Data?) {
        guard let mediaID, var item = item(mediaID) else { return }
        item.localPath = path
        item.bookmarkData = bookmark
        upsert(item)
    }

    fileprivate func complete(mediaID: String?, error: Error?) {
        guard let mediaID, var item = item(mediaID) else { return }
        tasks[mediaID] = nil
        if let error = error as NSError?, error.code != NSURLErrorCancelled {
            item.state = .failed
            item.errorMessage = error.localizedDescription
        } else if error == nil {
            item.state = .finished
            item.progress = 1
            item.errorMessage = ""
        }
        upsert(item)
        if tasks.isEmpty {
            let handler = backgroundCompletion
            backgroundCompletion = nil
            handler?()
        }
    }

    private func upsert(_ item: DownloadItem, persist: Bool = true) {
        if let index = items.firstIndex(where: { $0.mediaID == item.mediaID }) {
            items[index] = item
        } else {
            items.insert(item, at: 0)
        }
        if persist { library?.upsertDownload(item) }
    }

    private func ensureAssetSession() -> AVAssetDownloadURLSession {
        if let assetSession { return assetSession }
        let configuration = URLSessionConfiguration.background(withIdentifier: "com.layl.app.asset-downloads")
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        let session = AVAssetDownloadURLSession(configuration: configuration, assetDownloadDelegate: bridge, delegateQueue: .main)
        assetSession = session
        return session
    }

    nonisolated static func destination(for mediaID: String, suggested: URL) -> URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Layl/Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let ext = suggested.pathExtension.isEmpty ? "mp4" : suggested.pathExtension
        return folder.appendingPathComponent("\(mediaID).\(ext)")
    }
}

private final class SessionBridge: NSObject, URLSessionDownloadDelegate, AVAssetDownloadDelegate {
    weak var owner: DownloadCenter?

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let mediaID = downloadTask.taskDescription else { return }
        let destination = DownloadCenter.destination(for: mediaID, suggested: location)
        try? FileManager.default.removeItem(at: destination)
        do {
            try FileManager.default.moveItem(at: location, to: destination)
            Task { @MainActor in
                self.owner?.finishFile(mediaID: mediaID, path: destination.path)
            }
        } catch {
            Task { @MainActor in
                self.owner?.complete(mediaID: mediaID, error: error)
            }
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let fraction = totalBytesExpectedToWrite > 0 ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) : 0
        let mediaID = downloadTask.taskDescription
        Task { @MainActor in
            self.owner?.updateProgress(mediaID: mediaID, value: fraction)
        }
    }

    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, willDownloadTo location: URL) {
        let bookmark = try? location.bookmarkData()
        let mediaID = assetDownloadTask.taskDescription
        let path = location.path
        Task { @MainActor in
            self.owner?.noteHLSLocation(mediaID: mediaID, path: path, bookmark: bookmark)
        }
    }

    func urlSession(
        _ session: URLSession,
        assetDownloadTask: AVAssetDownloadTask,
        didLoad timeRange: CMTimeRange,
        totalTimeRangesLoaded loadedTimeRanges: [NSValue],
        timeRangeExpectedToLoad: CMTimeRange
    ) {
        let expected = timeRangeExpectedToLoad.duration.seconds
        guard expected.isFinite, expected > 0 else { return }
        let loaded = loadedTimeRanges.reduce(0.0) { partial, value in
            let seconds = value.timeRangeValue.duration.seconds
            return partial + (seconds.isFinite ? seconds : 0)
        }
        let mediaID = assetDownloadTask.taskDescription
        Task { @MainActor in
            self.owner?.updateProgress(mediaID: mediaID, value: loaded / expected)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let mediaID = task.taskDescription
        Task { @MainActor in
            let isFileDownload = task is URLSessionDownloadTask && !(task is AVAssetDownloadTask)
            if isFileDownload, error == nil { return }
            self.owner?.complete(mediaID: mediaID, error: error)
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { @MainActor in
            let handler = self.owner?.backgroundCompletion
            self.owner?.backgroundCompletion = nil
            handler?()
        }
    }
}
