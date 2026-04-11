import AVFoundation
import Foundation

actor VideoCache {
    static let shared = VideoCache()

    private let memoryCache = NSCache<NSURL, AVPlayerItem>()
    private var preloadTasks: [URL: Task<AVPlayerItem, Error>] = [:]

    private init() {
        memoryCache.countLimit = 10
    }

    func playerItem(for url: URL) async throws -> AVPlayerItem {
        if let cached = memoryCache.object(forKey: url as NSURL) {
            await cached.seek(to: .zero)
            return cached
        }

        if let task = preloadTasks[url] {
            return try await task.value
        }

        let task = Task<AVPlayerItem, Error> {
            let asset = AVURLAsset(url: url, options: [
                AVURLAssetPreferPreciseDurationAndTimingKey: true
            ])
            let _ = try await asset.load(.isPlayable)
            let item = AVPlayerItem(asset: asset)
            memoryCache.setObject(item, forKey: url as NSURL)
            return item
        }

        preloadTasks[url] = task
        let item = try await task.value
        preloadTasks.removeValue(forKey: url)
        return item
    }

    func preload(urls: [URL]) {
        for url in urls {
            if memoryCache.object(forKey: url as NSURL) != nil { continue }
            if preloadTasks[url] != nil { continue }

            preloadTasks[url] = Task {
                let asset = AVURLAsset(url: url)
                let _ = try await asset.load(.isPlayable)
                let item = AVPlayerItem(asset: asset)
                memoryCache.setObject(item, forKey: url as NSURL)
                return item
            }
        }
    }

    func evict(url: URL) {
        memoryCache.removeObject(forKey: url as NSURL)
        preloadTasks[url]?.cancel()
        preloadTasks.removeValue(forKey: url)
    }
}
